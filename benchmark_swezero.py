import argparse
import asyncio
import random
import statistics
import sys
import time
import uuid
from dataclasses import dataclass
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent / "tools"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from benchmark_sglang_metrics import (
    calculate_sglang_stage_throughput,
    fetch_sglang_metrics_snapshot,
    fetch_sglang_model_metadata,
    print_sglang_metrics_report,
    sglang_display_model_name,
)


DEFAULT_DATASET_PATH = "/workspace/datasets/swe-zero-12m"


@dataclass(frozen=True)
class TokenBucket:
    name: str
    min_tokens: int
    max_tokens: int
    weight: float


INPUT_TOKEN_BUCKETS = [
    TokenBucket("short_trace", 2000, 6000, 0.25),
    TokenBucket("standard_trace", 6000, 14000, 0.50),
    TokenBucket("long_trace", 14000, 24000, 0.20),
    TokenBucket("deep_trace", 24000, 32768, 0.05),
]

OUTPUT_TOKEN_BUCKETS = [
    TokenBucket("small_patch", 80, 400, 0.60),
    TokenBucket("standard_patch", 400, 1200, 0.32),
    TokenBucket("large_patch", 1200, 3000, 0.08),
]

INPUT_BUCKET_DESCRIPTIONS = {
    "short_trace": "Short SWE-ZERO agent trajectory context",
    "standard_trace": "Typical SWE-ZERO multi-turn agent trajectory",
    "long_trace": "Long SWE-ZERO investigation with broader repo context",
    "deep_trace": "Long-tail near-cap SWE-ZERO trajectory",
}

OUTPUT_BUCKET_DESCRIPTIONS = {
    "small_patch": "Concise next agent action",
    "standard_patch": "Normal next action with moderate reasoning",
    "large_patch": "Longer next action with expanded investigation context",
}

DEFAULT_MIN_INPUT = min(bucket.min_tokens for bucket in INPUT_TOKEN_BUCKETS)
DEFAULT_MAX_INPUT = max(bucket.max_tokens for bucket in INPUT_TOKEN_BUCKETS)
DEFAULT_MIN_OUTPUT = min(bucket.min_tokens for bucket in OUTPUT_TOKEN_BUCKETS)
DEFAULT_MAX_OUTPUT = max(bucket.max_tokens for bucket in OUTPUT_TOKEN_BUCKETS)


@dataclass
class RequestSample:
    request_id: int
    prompt: str
    messages: list[dict]
    input_len: int
    input_bucket: str
    output_len: int
    output_bucket: str
    temperature: float
    instance_id: str
    repo: str
    exit_status: str
    shard_name: str


@dataclass
class RequestResult:
    request_id: int
    prompt_tokens: int = 0
    completion_tokens: int = 0
    total_time: float = 0
    content_ttft: float = 0
    reasoning_ttft: float = 0
    input_len: int = 0
    output_len: int = 0
    input_bucket: str = ""
    output_bucket: str = ""
    finish_reason: str = ""
    success: bool = True
    error: str = None


def parse_args():
    parser = argparse.ArgumentParser(
        description="LLM Throughput Benchmark using SWE-ZERO agentic trajectories",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Example usage:
  python benchmark_swezero.py --preview-samples 2
  python benchmark_swezero.py --model kimi_k2 --num-prompts 100 --concurrency 2 --timeout 3600
  python benchmark_swezero.py --model kimi_k2 --num-prompts 1000 --seed 42
  python benchmark_swezero.py --dataset-path {DEFAULT_DATASET_PATH} --preview-samples 3
        """,
    )

    required = parser.add_argument_group("required arguments")
    required.add_argument("--model", type=str, required=False, help="Model name (required for live benchmark)")

    optional = parser.add_argument_group("optional arguments (with defaults)")
    optional.add_argument("--dataset-path", type=str, default=DEFAULT_DATASET_PATH, help=f"SWE-ZERO dataset root (default: {DEFAULT_DATASET_PATH})")
    optional.add_argument("--api-key", type=str, default="YOUR_API_KEY", help="API key (default: YOUR_API_KEY)")
    optional.add_argument("--concurrency", type=int, default=100, help="Number of concurrent requests (default: 100)")
    optional.add_argument("--num-prompts", type=int, default=100, help="Total number of prompts to run (default: 100)")
    optional.add_argument("--base-url", type=str, default="http://localhost:8000/v1", help="API base URL (default: http://localhost:8000/v1)")
    optional.add_argument("--port", type=int, default=8000, help="API port for the default localhost base URL (default: 8000)")
    optional.add_argument("--label", dest="run_label", type=str, help="Display label for benchmark/result headers (default: model name)")
    optional.add_argument("--min-input", type=int, default=DEFAULT_MIN_INPUT, help=f"Minimum approximate input tokens (default: {DEFAULT_MIN_INPUT})")
    optional.add_argument("--max-input", type=int, default=DEFAULT_MAX_INPUT, help=f"Maximum approximate input tokens (default: {DEFAULT_MAX_INPUT})")
    optional.add_argument("--min-output", type=int, default=DEFAULT_MIN_OUTPUT, help=f"Minimum output tokens (default: {DEFAULT_MIN_OUTPUT})")
    optional.add_argument("--max-output", type=int, default=DEFAULT_MAX_OUTPUT, help=f"Maximum output tokens (default: {DEFAULT_MAX_OUTPUT})")
    optional.add_argument("--timeout", type=int, default=600, help="Timeout per request in seconds (default: 600)")
    optional.add_argument("--warmup", type=int, default=3, help="Number of warmup requests (default: 3)")
    optional.add_argument("--seed", type=int, default=None, help="Random seed for reproducible dataset sampling (default: random)")
    optional.add_argument("--exit-status", type=str, default="any", help="Filter rows by exit_status, or 'any' (default: any)")
    optional.add_argument(
        "--trajectory-mode",
        choices=("full", "prefix"),
        default="full",
        help="Use full trajectory or random prefix ending on a user observation (default: full)",
    )
    optional.add_argument(
        "--max-sample-attempts",
        type=int,
        default=2000,
        help="Maximum candidate rows to try per requested prompt before falling back (default: 2000)",
    )
    optional.add_argument("--no-ignore-eos", action="store_true", help="Don't force full output length (default: force full output)")
    optional.add_argument(
        "--preview-samples",
        type=int,
        default=0,
        help="Print N sampled SWE-ZERO prompts and exit without API calls (default: 0)",
    )

    args = parser.parse_args()

    errors = []
    if args.run_label is not None:
        args.run_label = args.run_label.strip()
        if not args.run_label:
            errors.append("--label must not be empty")
    if args.port < 1 or args.port > 65535:
        errors.append("--port must be between 1 and 65535")
    if args.concurrency < 1:
        errors.append("--concurrency must be >= 1")
    if args.num_prompts < 1:
        errors.append("--num-prompts must be >= 1")
    if args.min_input < 1:
        errors.append("--min-input must be >= 1")
    if args.max_input < args.min_input:
        errors.append("--max-input must be >= --min-input")
    if args.min_output < 1:
        errors.append("--min-output must be >= 1")
    if args.max_output < args.min_output:
        errors.append("--max-output must be >= --min-output")
    if args.max_sample_attempts < 1:
        errors.append("--max-sample-attempts must be >= 1")
    if args.preview_samples < 0:
        errors.append("--preview-samples must be >= 0")
    if args.preview_samples == 0 and not args.model:
        errors.append("--model is required unless --preview-samples is used")

    dataset_root = Path(args.dataset_path)
    if not dataset_root.exists():
        errors.append(f"--dataset-path does not exist: {dataset_root}")
    elif not (dataset_root / "data").is_dir():
        errors.append(f"--dataset-path must contain a data/ directory: {dataset_root}")

    if errors:
        print("ERROR: Invalid arguments:")
        for err in errors:
            print(f"  - {err}")
        sys.exit(1)

    if not args.model:
        args.model = "preview-only"

    return args


args = parse_args()

BASE_URL_WAS_EXPLICIT = any(arg == "--base-url" or arg.startswith("--base-url=") for arg in sys.argv[1:])
BASE_URL = args.base_url if BASE_URL_WAS_EXPLICIT else f"http://localhost:{args.port}/v1"
API_KEY = args.api_key
MODEL = args.model
RUN_LABEL = args.run_label or MODEL
DATASET_PATH = Path(args.dataset_path)
NUM_PROMPTS = args.num_prompts
CONCURRENCY = args.concurrency
PORT = args.port
TIMEOUT_PER_REQUEST = args.timeout
WARMUP_REQUESTS = args.warmup
MIN_INPUT_TOKENS = args.min_input
MAX_INPUT_TOKENS = args.max_input
MIN_OUTPUT_TOKENS = args.min_output
MAX_OUTPUT_TOKENS = args.max_output
IGNORE_EOS = not args.no_ignore_eos
PREVIEW_SAMPLES = args.preview_samples
RANDOM_SEED = args.seed
EXIT_STATUS_FILTER = args.exit_status
TRAJECTORY_MODE = args.trajectory_mode
MAX_SAMPLE_ATTEMPTS = args.max_sample_attempts

client = None
if PREVIEW_SAMPLES == 0:
    try:
        from openai import AsyncOpenAI
    except ModuleNotFoundError:
        print("ERROR: `openai` package is not installed. Install it or run with --preview-samples.")
        sys.exit(1)

    client = AsyncOpenAI(
        base_url=BASE_URL,
        api_key=API_KEY,
        timeout=TIMEOUT_PER_REQUEST,
        max_retries=0,
    )


def seed_random():
    if RANDOM_SEED is None:
        random.seed()
    else:
        random.seed(RANDOM_SEED)


def run_header(prefix: str, label: str | None = None) -> str:
    return f"{prefix}: {label or RUN_LABEL} | Prompts: {NUM_PROMPTS} | Concurrency: {CONCURRENCY}"


def format_optional_tps(value: float | None) -> str:
    if value is None or value <= 0:
        return "N/A"
    return f"{value:.2f}"


def import_pyarrow_parquet():
    try:
        import pyarrow.parquet as pq
    except ModuleNotFoundError:
        print("ERROR: `pyarrow` is required to read SWE-ZERO Parquet shards.")
        print("Install it in this environment, for example:")
        print("  uv pip install --python /home/user/env_custom_uv/bin/python pyarrow")
        sys.exit(1)
    return pq


def estimate_tokens(text: str) -> int:
    return max(1, len(text) // 4)


def bucket_for_tokens(tokens: int) -> str:
    for bucket in INPUT_TOKEN_BUCKETS:
        if bucket.min_tokens <= tokens <= bucket.max_tokens:
            return bucket.name
    if tokens < INPUT_TOKEN_BUCKETS[0].min_tokens:
        return "below_range"
    return "above_range"


def pick_weighted_bucket(min_tokens: int, max_tokens: int, buckets: list[TokenBucket]) -> TokenBucket:
    candidates = []
    for bucket in buckets:
        lower = max(min_tokens, bucket.min_tokens)
        upper = min(max_tokens, bucket.max_tokens)
        if lower > upper:
            continue
        overlap = upper - lower + 1
        full_width = bucket.max_tokens - bucket.min_tokens + 1
        candidates.append((bucket, bucket.weight * (overlap / full_width)))

    if not candidates:
        raise ValueError("No token buckets overlap requested min/max input range")

    return random.choices([item[0] for item in candidates], weights=[item[1] for item in candidates], k=1)[0]


def pick_weighted_token_count(min_tokens: int, max_tokens: int, buckets: list[TokenBucket]) -> tuple[int, str]:
    candidates = []
    for bucket in buckets:
        lower = max(min_tokens, bucket.min_tokens)
        upper = min(max_tokens, bucket.max_tokens)
        if lower > upper:
            continue
        overlap = upper - lower + 1
        full_width = bucket.max_tokens - bucket.min_tokens + 1
        adjusted_weight = bucket.weight * (overlap / full_width)
        candidates.append((bucket, lower, upper, adjusted_weight))

    if not candidates:
        return random.randint(min_tokens, max_tokens), "uniform_clamped"

    chosen_bucket, lower, upper, _ = random.choices(candidates, weights=[c[3] for c in candidates], k=1)[0]
    return random.randint(lower, upper), chosen_bucket.name


def sample_output_tokens() -> tuple[int, str]:
    return pick_weighted_token_count(MIN_OUTPUT_TOKENS, MAX_OUTPUT_TOKENS, OUTPUT_TOKEN_BUCKETS)


class SweZeroSampler:
    def __init__(self, dataset_path: Path, exit_status_filter: str, trajectory_mode: str):
        self.dataset_path = dataset_path
        self.data_dir = dataset_path / "data"
        self.exit_status_filter = exit_status_filter
        self.trajectory_mode = trajectory_mode
        self.pq = import_pyarrow_parquet()
        self.shards = sorted(self.data_dir.glob("*.parquet"))
        if not self.shards:
            print(f"ERROR: No Parquet shards found under {self.data_dir}")
            print("Expected files like data/train-00000.parquet")
            sys.exit(1)

        self._shard_order = list(range(len(self.shards)))
        random.shuffle(self._shard_order)
        self._next_shard = 0
        self._rows = []
        self._current_shard_name = ""

    def _load_next_shard(self):
        while True:
            if self._next_shard >= len(self._shard_order):
                random.shuffle(self._shard_order)
                self._next_shard = 0

            shard = self.shards[self._shard_order[self._next_shard]]
            self._next_shard += 1

            table = self.pq.read_table(
                shard,
                columns=["instance_id", "repo", "messages", "exit_status", "duration_sec"],
            )
            rows = table.to_pylist()
            if self.exit_status_filter != "any":
                rows = [row for row in rows if row.get("exit_status") == self.exit_status_filter]
            if not rows:
                continue

            random.shuffle(rows)
            self._rows = rows
            self._current_shard_name = shard.name
            return

    def next_row(self) -> tuple[dict, str]:
        if not self._rows:
            self._load_next_shard()
        return self._rows.pop(), self._current_shard_name

    def select_messages(self, messages: list[dict]) -> list[dict]:
        if self.trajectory_mode == "full":
            return messages

        user_indices = [
            idx
            for idx, message in enumerate(messages)
            if message.get("role") == "user"
            and idx >= 3
            and any(prev.get("role") == "assistant" for prev in messages[:idx])
        ]
        if not user_indices:
            user_indices = [
                idx
                for idx, message in enumerate(messages)
                if message.get("role") == "user" and idx >= 1
            ]
        if not user_indices:
            return messages

        message_count = max(1, len(messages))
        weights = [((idx + 1) / message_count) ** 2 for idx in user_indices]
        end_idx = random.choices(user_indices, weights=weights, k=1)[0]
        return messages[: end_idx + 1]

    def normalize_chat_messages(self, messages: list[dict]) -> list[dict]:
        chat_messages = []
        valid_roles = {"system", "user", "assistant"}
        for message in messages:
            role = message.get("role") or "user"
            if role not in valid_roles:
                role = "user"
            content = message.get("content") or ""
            if content:
                chat_messages.append({"role": role, "content": content})

        if not chat_messages:
            return [{"role": "user", "content": "Continue the software-engineering task."}]
        return chat_messages

    def is_continuable(self, messages: list[dict]) -> bool:
        return bool(messages) and messages[-1].get("role") == "user"

    def render_transcript(self, messages: list[dict]) -> str:
        blocks = []
        for message in messages:
            role = message.get("role") or "unknown"
            content = message.get("content") or ""
            blocks.append(f"<{role}>\n{content}\n</{role}>")
        return "\n\n".join(blocks)

    def build_prompt(self, row: dict, shard_name: str, output_bucket: str) -> tuple[str, list[dict]]:
        del shard_name, output_bucket
        messages = self.select_messages(row.get("messages") or [])
        chat_messages = self.normalize_chat_messages(messages)
        return self.render_transcript(chat_messages), chat_messages

    def make_sample(
        self,
        request_id: int,
        row: dict,
        shard_name: str,
        prompt: str,
        messages: list[dict],
        approx_tokens: int,
        input_bucket: str,
        output_len: int,
        output_bucket: str,
    ) -> RequestSample:
        return RequestSample(
            request_id=request_id,
            prompt=prompt,
            messages=messages,
            input_len=approx_tokens,
            input_bucket=input_bucket,
            output_len=output_len,
            output_bucket=output_bucket,
            temperature=random.uniform(0.15, 0.45),
            instance_id=row.get("instance_id") or "",
            repo=row.get("repo") or "",
            exit_status=row.get("exit_status") or "",
            shard_name=shard_name,
        )

    def sample_request(self, request_id: int, output_len: int, output_bucket: str) -> RequestSample:
        target_bucket = pick_weighted_bucket(MIN_INPUT_TOKENS, MAX_INPUT_TOKENS, INPUT_TOKEN_BUCKETS)
        fallback_in_range = None
        fallback_bucket_match = None
        fallback_continuable = None

        for _ in range(MAX_SAMPLE_ATTEMPTS):
            row, shard_name = self.next_row()
            prompt, messages = self.build_prompt(row, shard_name, output_bucket)
            approx_tokens = estimate_tokens(prompt)
            in_requested_range = MIN_INPUT_TOKENS <= approx_tokens <= MAX_INPUT_TOKENS
            bucket_matches = (
                max(MIN_INPUT_TOKENS, target_bucket.min_tokens)
                <= approx_tokens
                <= min(MAX_INPUT_TOKENS, target_bucket.max_tokens)
            )
            continuable = self.is_continuable(messages)
            candidate = (row, shard_name, prompt, messages, approx_tokens)

            if in_requested_range and fallback_in_range is None:
                fallback_in_range = candidate
            if in_requested_range and continuable and fallback_continuable is None:
                fallback_continuable = candidate
            if bucket_matches and fallback_bucket_match is None:
                fallback_bucket_match = candidate

            if bucket_matches and continuable:
                return self.make_sample(
                    request_id,
                    row,
                    shard_name,
                    prompt,
                    messages,
                    approx_tokens,
                    target_bucket.name,
                    output_len,
                    output_bucket,
                )

        if fallback_continuable is not None:
            row, shard_name, prompt, messages, approx_tokens = fallback_continuable
            return self.make_sample(
                request_id,
                row,
                shard_name,
                prompt,
                messages,
                approx_tokens,
                bucket_for_tokens(approx_tokens),
                output_len,
                output_bucket,
            )

        if fallback_bucket_match is not None:
            row, shard_name, prompt, messages, approx_tokens = fallback_bucket_match
            return self.make_sample(
                request_id,
                row,
                shard_name,
                prompt,
                messages,
                approx_tokens,
                target_bucket.name,
                output_len,
                output_bucket,
            )

        if fallback_in_range is None:
            raise RuntimeError(
                f"Could not find a SWE-ZERO prompt in input range {MIN_INPUT_TOKENS}-{MAX_INPUT_TOKENS} "
                f"after {MAX_SAMPLE_ATTEMPTS} candidate rows. Try widening --min-input/--max-input."
            )

        row, shard_name, prompt, messages, approx_tokens = fallback_in_range
        return self.make_sample(
            request_id,
            row,
            shard_name,
            prompt,
            messages,
            approx_tokens,
            bucket_for_tokens(approx_tokens),
            output_len,
            output_bucket,
        )


def print_bucket_profile(buckets: list[TokenBucket], descriptions: dict[str, str]):
    for bucket in buckets:
        print(
            f"  {bucket.name:<18} "
            f"{bucket.min_tokens:>5}-{bucket.max_tokens:<5} "
            f"w={bucket.weight:.2f}  {descriptions.get(bucket.name, '')}"
        )


def build_request_samples(sample_count: int, *, show_progress: bool) -> list[RequestSample]:
    sampler = SweZeroSampler(DATASET_PATH, EXIT_STATUS_FILTER, TRAJECTORY_MODE)
    samples = []

    if show_progress:
        print(f"Sampling {sample_count} prompts from {DATASET_PATH} ({len(sampler.shards)} parquet shards)...")

    for idx in range(sample_count):
        output_len, output_bucket = sample_output_tokens()
        sample = sampler.sample_request(idx, output_len, output_bucket)
        samples.append(sample)

        if show_progress and sample_count >= 20 and (idx + 1) % max(1, sample_count // 20) == 0:
            print(f"\rSampled prompts: {idx + 1}/{sample_count}", end="", flush=True)

    if show_progress and sample_count >= 20:
        print()

    return samples


def print_sample_preview():
    print("\n" + "=" * 80)
    print(f"SWE-ZERO SAMPLE PREVIEW ({PREVIEW_SAMPLES} samples)")
    print("=" * 80)
    print(f"Dataset path:     {DATASET_PATH}")
    print(f"Trajectory mode:  {TRAJECTORY_MODE}")
    print(f"Exit status:      {EXIT_STATUS_FILTER}")
    print(f"Seed:             {RANDOM_SEED if RANDOM_SEED is not None else '(random)'}")
    print(f"Input clamp:      {MIN_INPUT_TOKENS} - {MAX_INPUT_TOKENS}")
    print(f"Output clamp:     {MIN_OUTPUT_TOKENS} - {MAX_OUTPUT_TOKENS}")
    print("\nInput bucket profile:")
    print_bucket_profile(INPUT_TOKEN_BUCKETS, INPUT_BUCKET_DESCRIPTIONS)
    print("\nOutput bucket profile:")
    print_bucket_profile(OUTPUT_TOKEN_BUCKETS, OUTPUT_BUCKET_DESCRIPTIONS)

    samples = build_request_samples(PREVIEW_SAMPLES, show_progress=False)

    for idx, sample in enumerate(samples):
        preview_chars = min(len(sample.prompt), 3200)

        print("\n" + "-" * 80)
        print(f"Sample {idx + 1}/{PREVIEW_SAMPLES}")
        print(f"Input tokens approximate: {sample.input_len} ({sample.input_bucket})")
        print(f"Output tokens target:     {sample.output_len} ({sample.output_bucket})")
        print(f"Repo:                     {sample.repo}")
        print(f"Instance:                 {sample.instance_id}")
        print(f"Exit status:              {sample.exit_status}")
        print(f"Shard:                    {sample.shard_name}")
        print(f"Chat messages:            {len(sample.messages)}")
        print("-" * 80)
        print(sample.prompt[:preview_chars])
        if len(sample.prompt) > preview_chars:
            print("\n...[truncated for preview]...")


def _value_has_text(value) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value)
    if isinstance(value, list):
        for part in value:
            if isinstance(part, str) and part:
                return True
            if isinstance(part, dict):
                if part.get("text") or part.get("content") or part.get("reasoning") or part.get("reasoning_content"):
                    return True
            else:
                for attr in ("text", "content", "reasoning", "reasoning_content"):
                    text = getattr(part, attr, None)
                    if isinstance(text, str) and text:
                        return True
        return False
    return False


def _delta_has_text(delta, attrs: tuple[str, ...]) -> bool:
    for attr in attrs:
        value = getattr(delta, attr, None)
        if _value_has_text(value):
            return True
    return False


async def run_single_request_streaming(sample: RequestSample, progress: dict) -> RequestResult:
    start = time.perf_counter()
    content_ttft = 0
    reasoning_ttft = 0
    completion_tokens = 0
    prompt_tokens = 0
    finish_reason = ""

    try:
        request_params = {
            "model": MODEL,
            "messages": sample.messages,
            "max_tokens": sample.output_len,
            "temperature": sample.temperature,
            "stream": True,
            "stream_options": {"include_usage": True},
        }

        if IGNORE_EOS:
            request_params["extra_body"] = {"ignore_eos": True}

        stream = await client.chat.completions.create(**request_params)

        async for chunk in stream:
            if chunk.choices:
                delta = chunk.choices[0].delta
                observed_at = None
                if content_ttft == 0 and _delta_has_text(delta, ("content",)):
                    observed_at = time.perf_counter()
                    content_ttft = observed_at - start
                if reasoning_ttft == 0 and _delta_has_text(delta, ("reasoning", "reasoning_content")):
                    if observed_at is None:
                        observed_at = time.perf_counter()
                    reasoning_ttft = observed_at - start
                chunk_finish_reason = chunk.choices[0].finish_reason
                if chunk_finish_reason:
                    finish_reason = chunk_finish_reason
            if chunk.usage:
                prompt_tokens = chunk.usage.prompt_tokens
                completion_tokens = chunk.usage.completion_tokens

        end = time.perf_counter()
        is_abort = finish_reason in {"abort", "error"}

        result = RequestResult(
            request_id=sample.request_id,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            total_time=end - start,
            content_ttft=content_ttft,
            reasoning_ttft=reasoning_ttft,
            input_len=sample.input_len,
            output_len=sample.output_len,
            input_bucket=sample.input_bucket,
            output_bucket=sample.output_bucket,
            finish_reason=finish_reason,
            success=not is_abort,
            error=f"finish_reason:{finish_reason}" if is_abort else None,
        )
    except asyncio.TimeoutError:
        result = RequestResult(
            request_id=sample.request_id,
            success=False,
            error="timeout",
            input_len=sample.input_len,
            output_len=sample.output_len,
            input_bucket=sample.input_bucket,
            output_bucket=sample.output_bucket,
            finish_reason=finish_reason,
        )
    except Exception as exc:
        result = RequestResult(
            request_id=sample.request_id,
            success=False,
            error=str(exc)[:120],
            input_len=sample.input_len,
            output_len=sample.output_len,
            input_bucket=sample.input_bucket,
            output_bucket=sample.output_bucket,
            finish_reason=finish_reason,
        )

    progress["completed"] += 1
    if not result.success:
        progress["failed"] += 1

    elapsed = time.perf_counter() - progress["start_time"]
    rate = progress["completed"] / elapsed if elapsed > 0 else 0
    print(
        f"\rProgress: {progress['completed']}/{NUM_PROMPTS} | Failed: {progress['failed']} | Rate: {rate:.2f} req/s",
        end="",
        flush=True,
    )
    return result


async def warmup():
    print(f"Warming up with {WARMUP_REQUESTS} requests...")
    for i in range(WARMUP_REQUESTS):
        try:
            await client.chat.completions.create(
                model=MODEL,
                messages=[{"role": "user", "content": f"Warmup request {uuid.uuid4()}. Print ok."}],
                max_tokens=50,
            )
            print(f"\rWarmup: {i + 1}/{WARMUP_REQUESTS}", end="", flush=True)
        except Exception as exc:
            print(f"\rWarmup {i + 1} failed: {exc}", end="", flush=True)
    print(" Done!")


def summarize_bucket_counts(results: list[RequestResult], attr: str, expected_buckets: list[TokenBucket]) -> list[str]:
    counts = {}
    for item in results:
        key = getattr(item, attr)
        counts[key] = counts.get(key, 0) + 1
    lines = []
    for bucket in expected_buckets:
        count = counts.get(bucket.name, 0)
        pct = (count / len(results) * 100) if results else 0
        lines.append(f"  {bucket.name:<18} {count:>4} ({pct:>5.1f}%)")
    for key in sorted(set(counts) - {bucket.name for bucket in expected_buckets}):
        count = counts[key]
        pct = (count / len(results) * 100) if results else 0
        lines.append(f"  {key:<18} {count:>4} ({pct:>5.1f}%)")
    return lines


def summarize_finish_reasons(results: list[RequestResult]) -> list[str]:
    counts = {}
    for item in results:
        key = item.finish_reason or "(none)"
        counts[key] = counts.get(key, 0) + 1
    lines = []
    total = len(results)
    for reason, count in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        pct = (count / total * 100) if total else 0
        lines.append(f"  {reason:<18} {count:>4} ({pct:>5.1f}%)")
    return lines


async def run_benchmark():
    if client is None:
        print("ERROR: Client not initialized. Use --preview-samples for preview mode or provide --model for benchmark mode.")
        return

    samples = build_request_samples(NUM_PROMPTS, show_progress=True)

    print("\n" + "=" * 60)
    print()
    print("NOTE: For accurate benchmarks, start server with:")
    print("  SGLang: --disable-radix-cache")
    print("  vLLM:   --no-enable-prefix-caching")
    print()
    print("=" * 60 + "\n")

    await warmup()
    sglang_model_metadata = fetch_sglang_model_metadata(BASE_URL, API_KEY)
    display_model = sglang_display_model_name(sglang_model_metadata, MODEL)
    display_run_label = RUN_LABEL if args.run_label else display_model
    sglang_metrics_start = fetch_sglang_metrics_snapshot(BASE_URL, API_KEY)

    progress = {"completed": 0, "failed": 0, "start_time": time.perf_counter()}

    print(f"\n{'=' * 60}")
    print(run_header("SWE-ZERO BENCHMARK", display_run_label))
    print(f"{'=' * 60}")
    print()
    print(f"SGLang Version:      {sglang_model_metadata.sglang_version}")
    print(f"Model:               {display_model}")
    print(f"Dataset path:        {DATASET_PATH}")
    print(f"Trajectory mode:     {TRAJECTORY_MODE}")
    print(f"Exit status:         {EXIT_STATUS_FILTER}")
    print(f"Seed:                {RANDOM_SEED if RANDOM_SEED is not None else '(random)'}")
    print(f"Port:                {PORT}")
    print(f"Base URL:            {BASE_URL}")
    print("Streaming:           True")
    print("Prompt format:       SWE-ZERO chat roles")
    print("Sampling policy:     prefers active trajectories ending on user observations")
    print("Radix cache:         disabled (expected)")
    print(f"Total requests:      {NUM_PROMPTS}")
    print(f"Concurrency:         {CONCURRENCY} (simulating {CONCURRENCY} agents)")
    print(f"Input tokens clamp:  {MIN_INPUT_TOKENS} - {MAX_INPUT_TOKENS} (approx chars/4)")
    print(f"Output tokens clamp: {MIN_OUTPUT_TOKENS} - {MAX_OUTPUT_TOKENS}")
    print("Input profile (pre-clamp):")
    print_bucket_profile(INPUT_TOKEN_BUCKETS, INPUT_BUCKET_DESCRIPTIONS)
    print("Output profile (pre-clamp):")
    print_bucket_profile(OUTPUT_TOKEN_BUCKETS, OUTPUT_BUCKET_DESCRIPTIONS)
    print(f"Timeout per request: {TIMEOUT_PER_REQUEST}s")
    print(f"ignore_eos:          {IGNORE_EOS} {'(forces full output)' if IGNORE_EOS else '(natural stopping)'}")
    print()
    print(f"{'=' * 60}\n")

    semaphore = asyncio.Semaphore(CONCURRENCY)

    async def bounded_request(sample: RequestSample):
        async with semaphore:
            return await run_single_request_streaming(sample, progress)

    overall_start = time.perf_counter()
    results = await asyncio.gather(*[bounded_request(sample) for sample in samples])
    overall_end = time.perf_counter()
    await asyncio.sleep(0.5)
    sglang_metrics_end = fetch_sglang_metrics_snapshot(BASE_URL, API_KEY)

    print(f"\n\n{'=' * 60}")

    successful = [r for r in results if r.success]
    failed = [r for r in results if not r.success]

    if not successful:
        print("\nAll requests failed!")
        for result in failed[:10]:
            print(f"  Request {result.request_id}: {result.error}")
        return

    total_prompt_tokens = sum(r.prompt_tokens for r in successful)
    total_completion_tokens = sum(r.completion_tokens for r in successful)
    total_tokens = total_prompt_tokens + total_completion_tokens
    total_wall_time = overall_end - overall_start

    latencies = [r.total_time for r in successful]
    content_ttfts = [r.content_ttft for r in successful if r.content_ttft > 0]
    reasoning_ttfts = [r.reasoning_ttft for r in successful if r.reasoning_ttft > 0]
    tps_per_request = [r.completion_tokens / r.total_time for r in successful if r.total_time > 0]

    def percentile(data, p):
        if not data:
            return 0
        sorted_data = sorted(data)
        idx = int(p * len(sorted_data))
        idx = min(idx, len(sorted_data) - 1)
        return sorted_data[idx]

    avg_input = statistics.mean([r.input_len for r in successful])
    avg_output = statistics.mean([r.output_len for r in successful])
    actual_avg_input = statistics.mean([r.prompt_tokens for r in successful])
    actual_avg_output = statistics.mean([r.completion_tokens for r in successful])
    sglang_stage_throughput = calculate_sglang_stage_throughput(
        MODEL,
        sglang_model_metadata,
        sglang_metrics_start,
        sglang_metrics_end,
    )

    print(run_header("RESULTS", display_run_label))
    print(f"{'=' * 60}")
    print()
    print(f"Successful requests:       {len(successful)}/{NUM_PROMPTS}")
    print(f"Failed requests:           {len(failed)}")
    print(f"Requests Seed:             {RANDOM_SEED if RANDOM_SEED is not None else '(random)'}")
    print(f"Avg input tokens (approx): {avg_input:.0f}")
    print(f"Avg input tokens (actual): {actual_avg_input:.0f}")
    print(f"Avg output tokens (cfg):   {avg_output:.0f}")
    print(f"Avg output tokens (actual): {actual_avg_output:.0f}")
    print(f"Total prompt tokens:       {total_prompt_tokens:,}")
    print(f"Total completion tokens:   {total_completion_tokens:,}")
    print(f"Total wall time:           {total_wall_time:.2f}s")

    print(f"\n{'=' * 60}")
    print()
    print("REQUEST MIX (successful):")
    print("Input buckets:")
    for line in summarize_bucket_counts(successful, "input_bucket", INPUT_TOKEN_BUCKETS):
        print(line)
    print("Output buckets:")
    for line in summarize_bucket_counts(successful, "output_bucket", OUTPUT_TOKEN_BUCKETS):
        print(line)
    print("Finish reasons (all):")
    for line in summarize_finish_reasons(results):
        print(line)

    print(f"\n{'=' * 60}")
    print()
    print("THROUGHPUT:")
    print(f"  Requests/sec:          {len(successful) / total_wall_time:.2f}")
    print(f"  SGLang Prefill tokens/sec: {format_optional_tps(sglang_stage_throughput.prefill_tokens_per_sec)}")
    print(f"  SGLang Decode tokens/sec:  {format_optional_tps(sglang_stage_throughput.decode_tokens_per_sec)}")
    print(f"  End-to-end Output tokens/sec: {total_completion_tokens / total_wall_time:.2f}")
    print(f"  Total tokens/sec:             {total_tokens / total_wall_time:.2f}")

    def print_ttft_stats(label: str, ttft_values: list[float]):
        print(f"{label}:")
        if not ttft_values:
            print("  Mean:                  N/A")
            print("  Median:                N/A")
            print("  P95:                   N/A")
            print("  P99:                   N/A")
            return

        print(f"  Mean:                  {statistics.mean(ttft_values) * 1000:.0f}ms")
        print(f"  Median:                {statistics.median(ttft_values) * 1000:.0f}ms")
        print(f"  P95:                   {percentile(ttft_values, 0.95) * 1000:.0f}ms")
        print(f"  P99:                   {percentile(ttft_values, 0.99) * 1000:.0f}ms")

    print(f"\n{'=' * 60}")
    print()
    print("TIME TO FIRST TOKEN (client-observed):")
    print_ttft_stats("Content", content_ttfts)
    print_ttft_stats("Reasoning", reasoning_ttfts)

    print("\nEND-TO-END LATENCY (client-observed):")
    print(f"  Mean:                  {statistics.mean(latencies):.2f}s")
    print(f"  Median:                {statistics.median(latencies):.2f}s")
    print(f"  P95:                   {percentile(latencies, 0.95):.2f}s")
    print(f"  P99:                   {percentile(latencies, 0.99):.2f}s")

    print("\nPER-REQUEST OUTPUT TPS (client-observed):")
    print(f"  Mean:                  {statistics.mean(tps_per_request):.2f}")
    print(f"  Std dev:               {statistics.stdev(tps_per_request) if len(tps_per_request) > 1 else 0:.2f}")
    print(f"  Min:                   {min(tps_per_request):.2f}")
    print(f"  Max:                   {max(tps_per_request):.2f}")

    print_sglang_metrics_report(
        BASE_URL,
        API_KEY,
        MODEL,
        sglang_metrics_start,
        sglang_metrics_end,
        metadata=sglang_model_metadata,
    )

    if failed:
        print("\nFAILED REQUESTS (first 10):")
        for result in failed[:10]:
            print(f"  Request {result.request_id}: {result.error}")
        if len(failed) > 10:
            print(f"  ... and {len(failed) - 10} more")


if __name__ == "__main__":
    seed_random()
    if PREVIEW_SAMPLES > 0:
        print_sample_preview()
    else:
        asyncio.run(run_benchmark())
