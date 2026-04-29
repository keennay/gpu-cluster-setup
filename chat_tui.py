#!/usr/bin/env python3
import curses
import json
import os
import textwrap
import time
import urllib.error
import urllib.request


API_KEY = os.environ.get("OPENAI_API_KEY", "YOUR_API_KEY")
MODEL = os.environ.get("OPENAI_MODEL", "qwen3")
MAX_TOKENS = int(os.environ.get("MAX_TOKENS", "32768"))
ENDPOINT = os.environ.get("OPENAI_ENDPOINT", "http://127.0.0.1:8000")


def safe_addnstr(stdscr, y, x, text, max_width, attr=0):
    height, width = stdscr.getmaxyx()
    if y < 0 or y >= height or x < 0 or x >= width or max_width <= 0:
        return

    available = min(max_width, width - x)
    if y == height - 1:
        available = min(available, width - x - 1)
    if available <= 0:
        return

    try:
        stdscr.addnstr(y, x, str(text)[:available], available, attr)
    except curses.error:
        pass


def sanitize_for_display(text):
    safe_chars = []
    for char in str(text):
        if char == "\t":
            safe_chars.append("    ")
        elif char == "\n":
            safe_chars.append(char)
        elif char.isprintable() and ord(char) < 128:
            safe_chars.append(char)
        elif char.isprintable():
            safe_chars.append("?")
    return "".join(safe_chars)


def completion_url(endpoint):
    endpoint = endpoint.strip() or ENDPOINT
    endpoint = endpoint.rstrip("/")
    if endpoint.endswith("/v1"):
        return f"{endpoint}/chat/completions"
    return f"{endpoint}/v1/chat/completions"


def chat_completion(endpoint, model, messages, temperature, max_tokens, reasoning_enabled):
    payload = {
        "model": model,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
    }
    if not reasoning_enabled:
        payload["chat_template_kwargs"] = {"enable_thinking": False}

    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        completion_url(endpoint),
        data=body,
        headers={
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            data = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        details = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {error.code}: {details}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"Connection error: {error.reason}") from error

    message = data["choices"][0]["message"]
    content = message.get("content")
    reasoning = message.get("reasoning")
    reasoning_text = reasoning.strip() if reasoning else ""
    content_text = content.strip() if content else ""
    parts = []

    if reasoning_enabled and reasoning_text and content_text:
        parts.append(f"Thinking:\n{reasoning_text}")

    if content_text:
        parts.append(f"Final:\n{content_text}" if parts else content_text)

    if parts:
        return "\n\n".join(parts)

    if reasoning_text:
        return reasoning_text

    return "[The server returned no assistant content.]"


def wrap_line(prefix, text, width, show_prefix=True):
    prefix_width = len(prefix)
    content_width = max(10, width - prefix_width)
    lines = textwrap.wrap(text, width=content_width) or [""]
    first_prefix = prefix if show_prefix else " " * prefix_width
    wrapped = [(first_prefix + lines[0])[:width]]
    wrapped.extend(((" " * prefix_width) + line)[:width] for line in lines[1:])
    return wrapped


def draw_box(stdscr, top, left, height, width, title="", active=False):
    if height < 2 or width < 2:
        return

    attr = curses.A_BOLD if active else curses.A_NORMAL
    horizontal = "-" * max(0, width - 2)
    safe_addnstr(stdscr, top, left, "+" + horizontal + "+", width, attr)
    for row in range(top + 1, top + height - 1):
        safe_addnstr(stdscr, row, left, "|" + (" " * max(0, width - 2)) + "|", width)
    safe_addnstr(stdscr, top + height - 1, left, "+" + horizontal + "+", width, attr)

    if title:
        label = f" {title} "
        safe_addnstr(stdscr, top, left + 2, label[: max(0, width - 4)], max(0, width - 4), attr)


SELECTABLE_FIELDS = {
    "message",
    "temperature",
    "system",
    "model",
    "endpoint",
    "max_tokens",
}


def get_layout(height, width, system_text=""):
    message_height = 3
    bottom_height = 3
    chat_top = 1
    button_width = 12
    controls_width = width - button_width
    temperature_width = 14
    model_width = 14
    endpoint_width = 28
    max_tokens_width = 14
    reasoning_width = 22
    system_width = controls_width - temperature_width
    system_inner_width = max(1, system_width - 4)
    system_lines = textwrap.wrap(sanitize_for_display(system_text), width=system_inner_width) or [""]
    min_chat_height = 4
    max_system_height = max(3, height - min_chat_height - message_height - bottom_height - 3)
    system_height = min(max(3, len(system_lines) + 2), max_system_height)
    input_height = message_height + system_height + bottom_height
    chat_height = max(min_chat_height, height - input_height - 3)
    input_top = chat_top + chat_height
    endpoint_left = model_width
    max_tokens_left = model_width + endpoint_width
    reasoning_left = model_width + endpoint_width + max_tokens_width
    reasoning_width = min(reasoning_width, controls_width - reasoning_left)
    system_top = input_top + message_height
    bottom_top = system_top + system_height

    return {
        "chat": (chat_top, 0, chat_height, width),
        "message": (input_top, 0, message_height, controls_width),
        "temperature": (system_top, 0, system_height, temperature_width),
        "system": (system_top, temperature_width, system_height, system_width),
        "model": (bottom_top, 0, bottom_height, model_width),
        "endpoint": (bottom_top, endpoint_left, bottom_height, endpoint_width),
        "max_tokens": (bottom_top, max_tokens_left, bottom_height, max_tokens_width),
        "reasoning": (bottom_top, reasoning_left, bottom_height, reasoning_width),
        "submit": (input_top, controls_width, message_height + system_height, button_width),
        "reset": (bottom_top, controls_width, bottom_height, button_width),
        "status_y": height - 2,
        "help_y": height - 1,
    }


def point_in_rect(y, x, rect):
    top, left, height, width = rect
    return top <= y < top + height and left <= x < left + width


def render_transcript_lines(transcript, width):
    rendered = []
    for role, text in transcript:
        prefix = {
            "system": "System: ",
            "user": "You:    ",
            "assistant": "Chat:   ",
            "error": "Error:  ",
        }.get(role, f"{role}: ")
        paragraphs = sanitize_for_display(text).splitlines() or [""]
        for index, paragraph in enumerate(paragraphs):
            rendered.extend(wrap_line(prefix, paragraph, width, show_prefix=index == 0))
        rendered.append("")
    return rendered


def max_scroll_offset(transcript, content_width, body_height):
    rendered = render_transcript_lines(transcript, content_width)
    return max(0, len(rendered) - body_height)


def wrap_field_text(text, width, height):
    if width <= 0 or height <= 0:
        return []

    lines = textwrap.wrap(sanitize_for_display(text), width=width) or [""]
    return lines[-height:]


def render(
    stdscr,
    transcript,
    message_buffer,
    temperature_buffer,
    model_buffer,
    endpoint_buffer,
    max_tokens_buffer,
    system_buffer,
    reasoning_enabled,
    focus,
    selected_field,
    scroll_offset,
    status,
):
    stdscr.erase()
    height, width = stdscr.getmaxyx()

    title = (
        f" local chat | full history | model={model_buffer} | "
        f"endpoint={endpoint_buffer} | max_tokens={max_tokens_buffer} "
    )
    safe_addnstr(stdscr, 0, 0, title[:width].ljust(width), width, curses.A_REVERSE)

    if height < 22 or width < 88:
        safe_addnstr(stdscr, 1, 0, "Terminal is too small. Resize to at least 88x22.", width)
        stdscr.refresh()
        return

    layout = get_layout(height, width, system_buffer)
    chat_top, _, chat_height, _ = layout["chat"]
    message_top, message_left, _, message_width = layout["message"]
    temperature_top, temperature_left, temperature_height, temperature_width = layout["temperature"]
    system_top, system_left, system_height, system_width = layout["system"]
    model_top, model_left, _, model_width = layout["model"]
    endpoint_top, endpoint_left, _, endpoint_width = layout["endpoint"]
    max_tokens_top, max_tokens_left, _, max_tokens_width = layout["max_tokens"]
    reasoning_top, reasoning_left, _, reasoning_width = layout["reasoning"]
    submit_top, submit_left, submit_height, submit_width = layout["submit"]
    reset_top, reset_left, reset_height, reset_width = layout["reset"]

    draw_box(stdscr, *layout["chat"], title="Chat", active=focus == "chat")
    draw_box(stdscr, *layout["message"], title="Message", active=focus == "message")
    draw_box(stdscr, *layout["temperature"], title="Temp", active=focus == "temperature")
    draw_box(stdscr, *layout["system"], title="System", active=focus == "system")
    draw_box(stdscr, *layout["model"], title="Model", active=focus == "model")
    draw_box(stdscr, *layout["endpoint"], title="Endpoint", active=focus == "endpoint")
    draw_box(stdscr, *layout["max_tokens"], title="Max Tokens", active=focus == "max_tokens")
    draw_box(stdscr, *layout["reasoning"], title="Reasoning", active=focus == "reasoning")
    draw_box(stdscr, *layout["submit"], active=focus == "submit")
    draw_box(stdscr, *layout["reset"], active=focus == "reset")

    body_height = chat_height - 2
    rendered = render_transcript_lines(transcript, width - 4)
    scroll_offset = min(scroll_offset, max(0, len(rendered) - body_height))
    end = len(rendered) - scroll_offset
    start = max(0, end - body_height)
    visible = rendered[start:end]
    for row, line in enumerate(visible, start=chat_top + 1):
        safe_addnstr(stdscr, row, 2, line[: width - 4], width - 4)

    if status:
        safe_addnstr(stdscr, layout["status_y"], 0, status[:width].ljust(width), width, curses.A_DIM)

    message_inner_width = message_width - 4
    temperature_inner_width = temperature_width - 4
    model_inner_width = model_width - 4
    endpoint_inner_width = endpoint_width - 4
    max_tokens_inner_width = max_tokens_width - 4
    system_inner_width = system_width - 4
    system_inner_height = system_height - 2
    reasoning_inner_width = reasoning_width - 4
    safe_addnstr(
        stdscr,
        message_top + 1,
        message_left + 2,
        message_buffer[-message_inner_width:],
        message_inner_width,
        curses.A_REVERSE if selected_field == "message" else curses.A_NORMAL,
    )
    safe_addnstr(
        stdscr,
        temperature_top + 1,
        temperature_left + 2,
        temperature_buffer[-temperature_inner_width:],
        temperature_inner_width,
        curses.A_REVERSE if selected_field == "temperature" else curses.A_NORMAL,
    )
    system_lines = wrap_field_text(system_buffer, system_inner_width, system_inner_height)
    for row, line in enumerate(system_lines, start=system_top + 1):
        safe_addnstr(
            stdscr,
            row,
            system_left + 2,
            line,
            system_inner_width,
            curses.A_REVERSE if selected_field == "system" else curses.A_NORMAL,
        )
    safe_addnstr(
        stdscr,
        model_top + 1,
        model_left + 2,
        model_buffer[-model_inner_width:],
        model_inner_width,
        curses.A_REVERSE if selected_field == "model" else curses.A_NORMAL,
    )
    safe_addnstr(
        stdscr,
        endpoint_top + 1,
        endpoint_left + 2,
        endpoint_buffer[-endpoint_inner_width:],
        endpoint_inner_width,
        curses.A_REVERSE if selected_field == "endpoint" else curses.A_NORMAL,
    )
    safe_addnstr(
        stdscr,
        max_tokens_top + 1,
        max_tokens_left + 2,
        max_tokens_buffer[-max_tokens_inner_width:],
        max_tokens_inner_width,
        curses.A_REVERSE if selected_field == "max_tokens" else curses.A_NORMAL,
    )
    checkbox = "[x] enabled" if reasoning_enabled else "[ ] disabled"
    safe_addnstr(
        stdscr,
        reasoning_top + 1,
        reasoning_left + 2,
        checkbox,
        reasoning_inner_width,
        curses.A_REVERSE if focus == "reasoning" else curses.A_NORMAL,
    )

    submit_attr = curses.A_REVERSE if focus == "submit" else curses.A_BOLD
    submit_label = "Submit"
    submit_label_y = submit_top + submit_height // 2
    submit_label_x = submit_left + max(1, (submit_width - len(submit_label)) // 2)
    safe_addnstr(
        stdscr,
        submit_label_y,
        submit_label_x,
        submit_label,
        submit_width - 2,
        submit_attr,
    )

    reset_attr = curses.A_REVERSE if focus == "reset" else curses.A_BOLD
    reset_label = "Reset"
    reset_label_y = reset_top + reset_height // 2
    reset_label_x = reset_left + max(1, (reset_width - len(reset_label)) // 2)
    safe_addnstr(
        stdscr,
        reset_label_y,
        reset_label_x,
        reset_label,
        reset_width - 2,
        reset_attr,
    )

    help_text = "Click fields/buttons | Tab focus | Space toggles Reasoning | Enter submits Message/Submit | /quit exits"
    safe_addnstr(stdscr, layout["help_y"], 0, help_text[:width].ljust(width), width, curses.A_REVERSE)

    if focus == "message":
        cursor_x = 2 + min(message_inner_width, len(message_buffer))
        stdscr.move(message_top + 1, cursor_x)
    elif focus == "temperature":
        cursor_x = temperature_left + 2 + min(temperature_inner_width, len(temperature_buffer))
        stdscr.move(temperature_top + 1, cursor_x)
    elif focus == "system":
        system_cursor_lines = wrap_field_text(system_buffer, system_inner_width, system_inner_height)
        cursor_row = system_top + max(1, len(system_cursor_lines))
        cursor_col = system_left + 2
        if system_cursor_lines:
            cursor_col += min(system_inner_width, len(system_cursor_lines[-1]))
        stdscr.move(cursor_row, cursor_col)
    elif focus == "model":
        cursor_x = model_left + 2 + min(model_inner_width, len(model_buffer))
        stdscr.move(model_top + 1, cursor_x)
    elif focus == "endpoint":
        cursor_x = endpoint_left + 2 + min(endpoint_inner_width, len(endpoint_buffer))
        stdscr.move(endpoint_top + 1, cursor_x)
    elif focus == "max_tokens":
        cursor_x = max_tokens_left + 2 + min(max_tokens_inner_width, len(max_tokens_buffer))
        stdscr.move(max_tokens_top + 1, cursor_x)
    elif focus == "reasoning":
        stdscr.move(reasoning_top + 1, reasoning_left + 3)
    elif focus == "reset":
        stdscr.move(reset_label_y, reset_label_x)
    elif focus == "chat":
        stdscr.move(chat_top + 1, 2)
    else:
        stdscr.move(submit_label_y, submit_label_x)

    stdscr.refresh()


def parse_temperature(value):
    try:
        temperature = float(value)
    except ValueError as error:
        raise ValueError("Temperature must be a number, like 0.2 or 0.8.") from error

    if not 0.0 <= temperature <= 2.0:
        raise ValueError("Temperature must be between 0.0 and 2.0.")

    return temperature


def parse_max_tokens(value):
    try:
        max_tokens = int(value)
    except ValueError as error:
        raise ValueError("Max Tokens must be an integer, like 200 or 800.") from error

    if max_tokens < 1:
        raise ValueError("Max Tokens must be at least 1.")

    return max_tokens


def main(stdscr):
    curses.curs_set(1)
    stdscr.keypad(True)
    mouse_events = curses.BUTTON1_CLICKED | curses.BUTTON1_PRESSED
    if hasattr(curses, "BUTTON4_PRESSED"):
        mouse_events |= curses.BUTTON4_PRESSED
    if hasattr(curses, "BUTTON5_PRESSED"):
        mouse_events |= curses.BUTTON5_PRESSED
    curses.mousemask(mouse_events)
    try:
        curses.mouseinterval(0)
    except curses.error:
        pass

    default_system = (
        "You are a helpful, conversational assistant. Answer directly and clearly. "
        "Be concise by default, but give more detail when useful. If you are unsure, "
        "say so instead of guessing. Ask a clarifying question when the request is "
        "ambiguous. Do not invent facts."
    )
    messages = [{"role": "system", "content": default_system}]
    transcript = [("system", default_system)]
    focus = "message"
    message_buffer = ""
    temperature_buffer = "0.7"
    model_buffer = MODEL
    endpoint_buffer = ENDPOINT
    max_tokens_buffer = str(MAX_TOKENS)
    system_buffer = default_system
    reasoning_enabled = True
    selected_field = None
    has_submitted_message = False
    displayed_system_text = default_system
    last_click_field = None
    last_click_time = 0.0
    scroll_offset = 0
    status = ""
    focus_order = [
        "chat",
        "message",
        "temperature",
        "system",
        "model",
        "endpoint",
        "max_tokens",
        "reasoning",
        "submit",
        "reset",
    ]

    def reset_chat():
        nonlocal messages, transcript, focus, message_buffer
        nonlocal temperature_buffer, model_buffer, endpoint_buffer, max_tokens_buffer, system_buffer
        nonlocal reasoning_enabled, selected_field, has_submitted_message, displayed_system_text
        nonlocal last_click_field, last_click_time, scroll_offset, status

        messages = [{"role": "system", "content": default_system}]
        transcript = [("system", default_system)]
        message_buffer = ""
        temperature_buffer = "0.7"
        model_buffer = MODEL
        endpoint_buffer = ENDPOINT
        max_tokens_buffer = str(MAX_TOKENS)
        system_buffer = default_system
        reasoning_enabled = True
        selected_field = None
        has_submitted_message = False
        displayed_system_text = default_system
        last_click_field = None
        last_click_time = 0.0
        scroll_offset = 0
        focus = "message"
        status = "Chat history reset."

    def submit_current_message():
        nonlocal focus, message_buffer, selected_field, has_submitted_message
        nonlocal displayed_system_text, scroll_offset, status

        user_text = message_buffer.strip()
        if user_text.lower() in {"/quit", "/exit"}:
            return "quit"
        if not user_text:
            status = "Type a message before submitting."
            return None

        try:
            temperature = parse_temperature(temperature_buffer.strip())
        except ValueError as error:
            status = str(error)
            focus = "temperature"
            return None

        try:
            max_tokens = parse_max_tokens(max_tokens_buffer.strip())
        except ValueError as error:
            status = str(error)
            focus = "max_tokens"
            return None

        model = model_buffer.strip() or MODEL
        endpoint = endpoint_buffer.strip() or ENDPOINT
        system_text = system_buffer.strip() or default_system
        messages[0] = {"role": "system", "content": system_text}
        if not has_submitted_message:
            transcript[0] = ("system", system_text)
            displayed_system_text = system_text
        elif system_text != displayed_system_text:
            transcript.append(("system", system_text))
            displayed_system_text = system_text
        transcript.append(("user", user_text))
        messages.append({"role": "user", "content": user_text})
        has_submitted_message = True
        message_buffer = ""
        selected_field = None
        scroll_offset = 0
        focus = "message"
        reasoning_status = "on" if reasoning_enabled else "off"
        status = (
            f"Sending {len(messages)} messages with temperature={temperature}, "
            f"max_tokens={max_tokens}, reasoning={reasoning_status}..."
        )
        render(
            stdscr,
            transcript,
            message_buffer,
            temperature_buffer,
            model_buffer,
            endpoint_buffer,
            max_tokens_buffer,
            system_buffer,
            reasoning_enabled,
            focus,
            selected_field,
            scroll_offset,
            status,
        )

        try:
            reply = chat_completion(endpoint, model, messages, temperature, max_tokens, reasoning_enabled)
        except RuntimeError as error:
            transcript.append(("error", str(error)))
            messages.pop()
        else:
            transcript.append(("assistant", reply))
            messages.append({"role": "assistant", "content": reply})

        scroll_offset = 0
        return None

    while True:
        render(
            stdscr,
            transcript,
            message_buffer,
            temperature_buffer,
            model_buffer,
            endpoint_buffer,
            max_tokens_buffer,
            system_buffer,
            reasoning_enabled,
            focus,
            selected_field,
            scroll_offset,
            status,
        )
        key = stdscr.get_wch()
        status = ""

        if key == curses.KEY_MOUSE:
            try:
                _, x, y, _, button_state = curses.getmouse()
            except curses.error:
                continue

            height, width = stdscr.getmaxyx()
            if height < 22 or width < 88:
                continue

            layout = get_layout(height, width, system_buffer)

            wheel_up = hasattr(curses, "BUTTON4_PRESSED") and button_state & curses.BUTTON4_PRESSED
            wheel_down = hasattr(curses, "BUTTON5_PRESSED") and button_state & curses.BUTTON5_PRESSED
            if point_in_rect(y, x, layout["chat"]) and (wheel_up or wheel_down):
                body_height = layout["chat"][2] - 2
                max_offset = max_scroll_offset(transcript, width - 4, body_height)
                if wheel_up:
                    scroll_offset = min(max_offset, scroll_offset + 3)
                else:
                    scroll_offset = max(0, scroll_offset - 3)
                focus = "chat"
                selected_field = None
                continue

            if not button_state & (curses.BUTTON1_CLICKED | curses.BUTTON1_PRESSED):
                continue

            clicked_field = None
            if point_in_rect(y, x, layout["chat"]):
                clicked_field = "chat"
            elif point_in_rect(y, x, layout["message"]):
                clicked_field = "message"
            elif point_in_rect(y, x, layout["temperature"]):
                clicked_field = "temperature"
            elif point_in_rect(y, x, layout["system"]):
                clicked_field = "system"
            elif point_in_rect(y, x, layout["model"]):
                clicked_field = "model"
            elif point_in_rect(y, x, layout["endpoint"]):
                clicked_field = "endpoint"
            elif point_in_rect(y, x, layout["max_tokens"]):
                clicked_field = "max_tokens"
            elif point_in_rect(y, x, layout["reasoning"]):
                clicked_field = "reasoning"
            elif point_in_rect(y, x, layout["submit"]):
                clicked_field = "submit"
            elif point_in_rect(y, x, layout["reset"]):
                clicked_field = "reset"

            if clicked_field is None:
                selected_field = None
                last_click_field = None
                last_click_time = 0.0
                continue

            now = time.monotonic()
            double_clicked = (
                clicked_field == last_click_field
                and now - last_click_time <= 0.35
            )
            last_click_field = clicked_field
            last_click_time = now

            focus = clicked_field
            if double_clicked and clicked_field in SELECTABLE_FIELDS:
                selected_field = clicked_field
                continue

            selected_field = None
            if clicked_field == "reasoning":
                reasoning_enabled = not reasoning_enabled
            elif clicked_field == "submit":
                if submit_current_message() == "quit":
                    break
            elif clicked_field == "reset":
                reset_chat()
            continue

        if key == "\t":
            selected_field = None
            focus = focus_order[(focus_order.index(focus) + 1) % len(focus_order)]
            continue

        if key == curses.KEY_BTAB:
            selected_field = None
            focus = focus_order[(focus_order.index(focus) - 1) % len(focus_order)]
            continue

        should_submit = key == "\x13" or (
            key in ("\n", "\r", curses.KEY_ENTER) and focus in {"message", "submit"}
        )

        if should_submit:
            if submit_current_message() == "quit":
                break
            continue

        if key in ("\n", "\r", curses.KEY_ENTER) and focus == "reset":
            selected_field = None
            reset_chat()
            continue

        if key in ("\n", "\r", curses.KEY_ENTER, " ") and focus == "reasoning":
            selected_field = None
            reasoning_enabled = not reasoning_enabled
            continue

        if key in ("\n", "\r", curses.KEY_ENTER):
            continue

        if key in (curses.KEY_BACKSPACE, "\b", "\x7f"):
            clear_selected = selected_field == focus
            selected_field = None
            if focus == "message":
                if clear_selected:
                    message_buffer = ""
                else:
                    message_buffer = message_buffer[:-1]
            elif focus == "temperature":
                if clear_selected:
                    temperature_buffer = ""
                else:
                    temperature_buffer = temperature_buffer[:-1]
            elif focus == "system":
                if clear_selected:
                    system_buffer = ""
                else:
                    system_buffer = system_buffer[:-1]
            elif focus == "model":
                if clear_selected:
                    model_buffer = ""
                else:
                    model_buffer = model_buffer[:-1]
            elif focus == "endpoint":
                if clear_selected:
                    endpoint_buffer = ""
                else:
                    endpoint_buffer = endpoint_buffer[:-1]
            elif focus == "max_tokens":
                if clear_selected:
                    max_tokens_buffer = ""
                else:
                    max_tokens_buffer = max_tokens_buffer[:-1]
            continue

        if key == curses.KEY_DC:
            if selected_field != focus:
                continue
            selected_field = None
            if focus == "message":
                message_buffer = ""
            elif focus == "temperature":
                temperature_buffer = ""
            elif focus == "system":
                system_buffer = ""
            elif focus == "model":
                model_buffer = ""
            elif focus == "endpoint":
                endpoint_buffer = ""
            elif focus == "max_tokens":
                max_tokens_buffer = ""
            continue

        if key == "\x1b":
            selected_field = None
            if focus == "message":
                message_buffer = ""
            elif focus == "temperature":
                temperature_buffer = "0.7"
            elif focus == "max_tokens":
                max_tokens_buffer = str(MAX_TOKENS)
            elif focus == "model":
                model_buffer = MODEL
            elif focus == "endpoint":
                endpoint_buffer = ENDPOINT
            elif focus == "system":
                system_buffer = default_system
            elif focus == "reasoning":
                reasoning_enabled = True
            else:
                focus = "message"
            continue

        if isinstance(key, str) and key.isprintable():
            replace_selected = selected_field == focus
            selected_field = None
            if focus == "message":
                message_buffer = key if replace_selected else message_buffer + key
            elif focus == "temperature":
                temperature_buffer = key if replace_selected else temperature_buffer + key
            elif focus == "system":
                system_buffer = key if replace_selected else system_buffer + key
            elif focus == "model":
                model_buffer = key if replace_selected else model_buffer + key
            elif focus == "endpoint":
                endpoint_buffer = key if replace_selected else endpoint_buffer + key
            elif focus == "max_tokens":
                max_tokens_buffer = key if replace_selected else max_tokens_buffer + key


if __name__ == "__main__":
    curses.wrapper(main)
