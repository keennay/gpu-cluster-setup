import importlib.metadata
import json
import re
import statistics
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass


HTTP_TIMEOUT_SECONDS = 5


@dataclass(frozen=True)
class PrometheusSample:
    name: str
    labels: tuple[tuple[str, str], ...]
    value: float


@dataclass
class SGLangMetricsSnapshot:
    endpoint: str
    samples: list[PrometheusSample]
    error: str = ""


@dataclass
class HistogramSummary:
    count: float = 0
    total: float = 0
    mean: float = 0
    p95: float | None = None
    p99: float | None = None


@dataclass
class SGLangModelMetadata:
    served_models: list[str]
    sglang_version: str = "N/A"
    max_model_len: int | None = None
    model_path: str = ""
    model_type: str = ""
    architectures: list[str] | None = None
    error: str = ""


_METRIC_RE = re.compile(
    r"^([a-zA-Z_:][a-zA-Z0-9_:]*)(?:\{([^}]*)\})?\s+"
    r"([-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?|[-+]?Inf|NaN)(?:\s|$)"
)
_LABEL_RE = re.compile(r'([a-zA-Z_][a-zA-Z0-9_]*)="((?:\\.|[^"\\])*)"')


def sglang_root_url(base_url: str) -> str:
    parsed = urllib.parse.urlsplit(base_url)
    path = parsed.path.rstrip("/")
    if path.endswith("/v1"):
        path = path[:-3]
    return urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, path.rstrip("/"), "", ""))


def sglang_metrics_endpoint(base_url: str) -> str:
    return f"{sglang_root_url(base_url)}/metrics"


def _headers(api_key: str | None) -> dict[str, str]:
    headers = {"Accept": "application/json, text/plain;q=0.9, */*;q=0.8"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    return headers


def _http_get_text(url: str, api_key: str | None = None) -> tuple[str, str]:
    request = urllib.request.Request(url, headers=_headers(api_key))
    try:
        with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT_SECONDS) as response:
            return response.read().decode("utf-8", errors="replace"), ""
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        return "", str(exc)


def _http_get_json(url: str, api_key: str | None = None) -> tuple[dict, str]:
    text, error = _http_get_text(url, api_key)
    if error:
        return {}, error
    try:
        return json.loads(text), ""
    except json.JSONDecodeError as exc:
        return {}, f"invalid JSON from {url}: {exc}"


def _decode_label_value(value: str) -> str:
    return value.replace(r"\"", '"').replace(r"\\", "\\").replace(r"\n", "\n")


def _parse_labels(raw_labels: str | None) -> tuple[tuple[str, str], ...]:
    if not raw_labels:
        return ()
    labels = [(match.group(1), _decode_label_value(match.group(2))) for match in _LABEL_RE.finditer(raw_labels)]
    return tuple(sorted(labels))


def parse_prometheus_metrics(text: str) -> list[PrometheusSample]:
    samples: list[PrometheusSample] = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        match = _METRIC_RE.match(line)
        if not match:
            continue
        try:
            value = float(match.group(3))
        except ValueError:
            continue
        samples.append(
            PrometheusSample(
                name=match.group(1),
                labels=_parse_labels(match.group(2)),
                value=value,
            )
        )
    return samples


def fetch_sglang_metrics_snapshot(base_url: str, api_key: str | None = None) -> SGLangMetricsSnapshot:
    endpoint = sglang_metrics_endpoint(base_url)
    text, error = _http_get_text(endpoint, api_key)
    if error:
        return SGLangMetricsSnapshot(endpoint=endpoint, samples=[], error=error)
    return SGLangMetricsSnapshot(endpoint=endpoint, samples=parse_prometheus_metrics(text))


def fetch_sglang_version() -> str:
    for package_name in ("sglang-kt", "sglang_kt", "sglang"):
        try:
            return importlib.metadata.version(package_name)
        except importlib.metadata.PackageNotFoundError:
            pass

    try:
        from sglang.version import __version__

        return str(__version__)
    except Exception:
        pass

    try:
        import sglang

        version = getattr(sglang, "__version__", None)
        if version:
            return str(version)
    except Exception:
        pass

    return "N/A"


def fetch_sglang_model_metadata(base_url: str, api_key: str | None = None) -> SGLangModelMetadata:
    models_url = f"{base_url.rstrip('/')}/models"
    model_info_url = f"{sglang_root_url(base_url)}/model_info"

    errors = []
    served_models: list[str] = []
    max_model_len = None
    model_path = ""
    model_type = ""
    architectures = None

    models_json, error = _http_get_json(models_url, api_key)
    if error:
        errors.append(error)
    else:
        for model in models_json.get("data", []):
            model_id = model.get("id")
            if model_id:
                served_models.append(str(model_id))
            if max_model_len is None and model.get("max_model_len") is not None:
                try:
                    max_model_len = int(model["max_model_len"])
                except (TypeError, ValueError):
                    pass

    info_json, error = _http_get_json(model_info_url, api_key)
    if error:
        errors.append(error)
    else:
        model_path = str(info_json.get("model_path") or "")
        model_type = str(info_json.get("model_type") or "")
        raw_architectures = info_json.get("architectures")
        if isinstance(raw_architectures, list):
            architectures = [str(item) for item in raw_architectures]

    return SGLangModelMetadata(
        served_models=served_models,
        sglang_version=fetch_sglang_version(),
        max_model_len=max_model_len,
        model_path=model_path,
        model_type=model_type,
        architectures=architectures,
        error="; ".join(errors),
    )


def sglang_display_model_name(metadata: SGLangModelMetadata, fallback: str) -> str:
    path = metadata.model_path.rstrip("/")
    for part in reversed(path.split("/")):
        if part.startswith("models--"):
            pieces = part.split("--")
            if pieces:
                return pieces[-1]

    if path:
        last_part = path.rsplit("/", 1)[-1]
        if last_part and not re.fullmatch(r"[0-9a-f]{20,}", last_part):
            return last_part

    if metadata.served_models:
        return metadata.served_models[0]
    return fallback


def _labels_dict(sample: PrometheusSample) -> dict[str, str]:
    return dict(sample.labels)


def _sample_matches(
    sample: PrometheusSample,
    model_name: str | None = None,
    required_labels: dict[str, str] | None = None,
) -> bool:
    labels = _labels_dict(sample)
    if model_name is not None and labels.get("model_name") not in (None, model_name):
        return False
    if required_labels:
        for key, expected in required_labels.items():
            if labels.get(key) != expected:
                return False
    return True


def _sample_key(sample: PrometheusSample) -> tuple[str, tuple[tuple[str, str], ...]]:
    return sample.name, sample.labels


def _sample_index(snapshot: SGLangMetricsSnapshot) -> dict[tuple[str, tuple[tuple[str, str], ...]], float]:
    return {_sample_key(sample): sample.value for sample in snapshot.samples}


def _counter_delta(
    start: SGLangMetricsSnapshot,
    end: SGLangMetricsSnapshot,
    name: str,
    model_name: str | None = None,
    required_labels: dict[str, str] | None = None,
) -> float:
    start_index = _sample_index(start)
    total = 0.0
    for sample in end.samples:
        if sample.name != name or not _sample_matches(sample, model_name, required_labels):
            continue
        delta = sample.value - start_index.get(_sample_key(sample), 0.0)
        total += max(0.0, delta)
    return total


def _gauge_value(
    snapshot: SGLangMetricsSnapshot,
    name: str,
    model_name: str | None = None,
    required_labels: dict[str, str] | None = None,
) -> float | None:
    values = [
        sample.value
        for sample in snapshot.samples
        if sample.name == name and _sample_matches(sample, model_name, required_labels)
    ]
    if not values:
        return None
    return max(values)


def _parse_bucket_bound(value: str) -> float:
    if value == "+Inf":
        return float("inf")
    return float(value)


def _histogram_groups(
    start: SGLangMetricsSnapshot,
    end: SGLangMetricsSnapshot,
    base_name: str,
    model_name: str | None = None,
    required_labels: dict[str, str] | None = None,
) -> dict[tuple[tuple[str, str], ...], dict[str, object]]:
    start_index = _sample_index(start)
    groups: dict[tuple[tuple[str, str], ...], dict[str, object]] = {}

    for sample in end.samples:
        if not sample.name.startswith(f"{base_name}_") or not _sample_matches(sample, model_name, required_labels):
            continue
        labels = _labels_dict(sample)
        group_labels = tuple(sorted((key, value) for key, value in labels.items() if key != "le"))
        group = groups.setdefault(group_labels, {"sum": 0.0, "count": 0.0, "buckets": {}})
        delta = sample.value - start_index.get(_sample_key(sample), 0.0)
        delta = max(0.0, delta)

        if sample.name == f"{base_name}_sum":
            group["sum"] = delta
        elif sample.name == f"{base_name}_count":
            group["count"] = delta
        elif sample.name == f"{base_name}_bucket" and "le" in labels:
            buckets = group["buckets"]
            assert isinstance(buckets, dict)
            buckets[_parse_bucket_bound(labels["le"])] = delta

    return groups


def _quantile_from_buckets(buckets: dict[float, float], count: float, quantile: float) -> float | None:
    if count <= 0:
        return None
    target = count * quantile
    for upper_bound, bucket_count in sorted(buckets.items(), key=lambda item: item[0]):
        if bucket_count >= target:
            if upper_bound == float("inf"):
                return None
            return upper_bound
    return None


def _group_to_summary(group: dict[str, object]) -> HistogramSummary:
    count = float(group.get("count") or 0.0)
    total = float(group.get("sum") or 0.0)
    buckets = group.get("buckets") or {}
    assert isinstance(buckets, dict)
    mean = total / count if count > 0 else 0.0
    return HistogramSummary(
        count=count,
        total=total,
        mean=mean,
        p95=_quantile_from_buckets(buckets, count, 0.95),
        p99=_quantile_from_buckets(buckets, count, 0.99),
    )


def _merged_histogram_summary(
    start: SGLangMetricsSnapshot,
    end: SGLangMetricsSnapshot,
    base_name: str,
    model_name: str | None = None,
    required_labels: dict[str, str] | None = None,
) -> HistogramSummary:
    groups = _histogram_groups(start, end, base_name, model_name, required_labels)
    merged = {"sum": 0.0, "count": 0.0, "buckets": {}}
    for group in groups.values():
        merged["sum"] += float(group.get("sum") or 0.0)
        merged["count"] += float(group.get("count") or 0.0)
        buckets = group.get("buckets") or {}
        assert isinstance(buckets, dict)
        merged_buckets = merged["buckets"]
        assert isinstance(merged_buckets, dict)
        for upper_bound, count in buckets.items():
            merged_buckets[upper_bound] = merged_buckets.get(upper_bound, 0.0) + count
    return _group_to_summary(merged)


def _average_histogram_summary_by_label(
    start: SGLangMetricsSnapshot,
    end: SGLangMetricsSnapshot,
    base_name: str,
    average_label: str,
    model_name: str | None = None,
    required_labels: dict[str, str] | None = None,
) -> HistogramSummary:
    groups = _histogram_groups(start, end, base_name, model_name, required_labels)
    summaries = []
    seen = set()
    for labels, group in groups.items():
        label_dict = dict(labels)
        if average_label not in label_dict:
            continue
        label_value = label_dict[average_label]
        if label_value in seen:
            continue
        seen.add(label_value)
        summary = _group_to_summary(group)
        if summary.count > 0:
            summaries.append(summary)

    if not summaries:
        return HistogramSummary()

    p95_values = [summary.p95 for summary in summaries if summary.p95 is not None]
    p99_values = [summary.p99 for summary in summaries if summary.p99 is not None]
    return HistogramSummary(
        count=statistics.mean(summary.count for summary in summaries),
        total=statistics.mean(summary.total for summary in summaries),
        mean=statistics.mean(summary.mean for summary in summaries),
        p95=statistics.mean(p95_values) if p95_values else None,
        p99=statistics.mean(p99_values) if p99_values else None,
    )


def _metric_model_names(snapshot: SGLangMetricsSnapshot) -> list[str]:
    names = sorted(
        {
            labels["model_name"]
            for sample in snapshot.samples
            for labels in [_labels_dict(sample)]
            if labels.get("model_name")
        }
    )
    return names


def _select_metrics_model(
    benchmark_model: str,
    metadata: SGLangModelMetadata,
    start: SGLangMetricsSnapshot,
    end: SGLangMetricsSnapshot,
) -> str | None:
    metric_names = set(_metric_model_names(start)) | set(_metric_model_names(end))
    if benchmark_model in metric_names:
        return benchmark_model
    for model in metadata.served_models:
        if model in metric_names:
            return model
    if len(metric_names) == 1:
        return next(iter(metric_names))
    return benchmark_model or None


def _fmt_int(value: float | int | None) -> str:
    if value is None:
        return "N/A"
    return f"{int(round(value)):,}"


def _fmt_float(value: float | None, digits: int = 2) -> str:
    if value is None:
        return "N/A"
    return f"{value:.{digits}f}"


def _fmt_ms(value: float | None) -> str:
    if value is None or value <= 0:
        return "N/A"
    return f"{value * 1000:.0f}ms"


def _fmt_ms_bound(value: float | None) -> str:
    formatted = _fmt_ms(value)
    return formatted if formatted == "N/A" else f"<={formatted}"


def _fmt_seconds(value: float | None) -> str:
    if value is None or value <= 0:
        return "N/A"
    return f"{value:.2f}s"


def _fmt_seconds_bound(value: float | None) -> str:
    formatted = _fmt_seconds(value)
    return formatted if formatted == "N/A" else f"<={formatted}"


def _fmt_tps(value: float | None) -> str:
    if value is None or value <= 0:
        return "N/A"
    return f"{value:.2f}"


def _fmt_percent(value: float | None) -> str:
    if value is None:
        return "N/A"
    return f"{value * 100:.2f}%"


def _histogram_enabled(summary: HistogramSummary) -> str:
    if summary.count <= 0:
        return "not observed"
    return f"enabled ({_fmt_int(summary.count)} samples)"


def print_sglang_metrics_report(
    base_url: str,
    api_key: str | None,
    benchmark_model: str,
    start: SGLangMetricsSnapshot,
    end: SGLangMetricsSnapshot,
    metadata: SGLangModelMetadata | None = None,
) -> None:
    metadata = metadata or fetch_sglang_model_metadata(base_url, api_key)
    metrics_model = _select_metrics_model(benchmark_model, metadata, start, end)

    print("\n" + "=" * 60)
    print()
    print("SGLang /metrics:")
    print(f"  SGLang Version:              {metadata.sglang_version}")
    print(f"  Metrics endpoint:              {end.endpoint}")

    if start.error or end.error:
        print(f"  Status:                        unavailable ({start.error or end.error})")
        return

    served_models = ", ".join(metadata.served_models) if metadata.served_models else "N/A"
    metric_labels = ", ".join(_metric_model_names(end)) or "N/A"
    architecture = ", ".join(metadata.architectures or []) or "N/A"

    print(f"  Model:                         {sglang_display_model_name(metadata, benchmark_model)}")
    print(f"  Served model id:               {served_models}")
    print(f"  Metrics model label:           {metrics_model or metric_labels}")
    print(f"  Model path:                    {metadata.model_path or 'N/A'}")
    print(f"  Model type:                    {metadata.model_type or 'N/A'}")
    print(f"  Architecture:                  {architecture}")
    print(f"  Max model length:              {_fmt_int(metadata.max_model_len)}")

    ttft = _merged_histogram_summary(start, end, "sglang:time_to_first_token_seconds", metrics_model)
    e2e = _merged_histogram_summary(start, end, "sglang:e2e_request_latency_seconds", metrics_model)
    queue = _average_histogram_summary_by_label(start, end, "sglang:queue_time_seconds", "tp_rank", metrics_model)
    prefill = _average_histogram_summary_by_label(
        start,
        end,
        "sglang:per_stage_req_latency_seconds",
        "tp_rank",
        metrics_model,
        {"stage": "prefill_forward"},
    )
    decode_itl = _merged_histogram_summary(start, end, "sglang:inter_token_latency_seconds", metrics_model)
    prompt_hist = _merged_histogram_summary(start, end, "sglang:prompt_tokens_histogram", metrics_model)
    generation_hist = _merged_histogram_summary(start, end, "sglang:generation_tokens_histogram", metrics_model)

    prompt_tokens = _counter_delta(start, end, "sglang:prompt_tokens_total", metrics_model)
    generation_tokens = _counter_delta(start, end, "sglang:generation_tokens_total", metrics_model)
    prefill_tps = prompt_tokens / prefill.total if prefill.total > 0 else None
    decode_tps = decode_itl.count / decode_itl.total if decode_itl.total > 0 else None

    print(f"  Samples observed:              {_fmt_int(ttft.count or e2e.count)}")

    print("\n  Queue time:")
    print(f"    Mean:                        {_fmt_ms(queue.mean)}")
    print(f"    P95:                         {_fmt_ms_bound(queue.p95)}")
    print(f"    P99:                         {_fmt_ms_bound(queue.p99)}")

    print("\n  TTFT:")
    print(f"    Mean:                        {_fmt_ms(ttft.mean)}")
    print(f"    P95:                         {_fmt_ms_bound(ttft.p95)}")
    print(f"    P99:                         {_fmt_ms_bound(ttft.p99)}")

    print("\n  Prefill:")
    print(f"    Forward mean:                {_fmt_ms(prefill.mean)}")
    print(f"    Forward P95:                 {_fmt_ms_bound(prefill.p95)}")
    print(f"    Prompt tokens:               {_fmt_int(prompt_tokens)}")
    print(f"    Prompt tokens/sec approx:    {_fmt_tps(prefill_tps)}")
    print(f"    Prompt token histogram:      {_histogram_enabled(prompt_hist)}")

    print("\n  Decode:")
    print(f"    Inter-token latency mean:    {_fmt_ms(decode_itl.mean)}")
    print(f"    Inter-token latency P95:     {_fmt_ms_bound(decode_itl.p95)}")
    print(f"    Generation tokens:           {_fmt_int(generation_tokens)}")
    print(f"    Decode tokens/sec approx:    {_fmt_tps(decode_tps)}")
    print(f"    Generation token histogram:  {_histogram_enabled(generation_hist)}")

    print("\n  End-to-end request latency:")
    print(f"    Mean:                        {_fmt_seconds(e2e.mean)}")
    print(f"    P95:                         {_fmt_seconds_bound(e2e.p95)}")
    print(f"    P99:                         {_fmt_seconds_bound(e2e.p99)}")

    print("\n  Scheduler / memory final scrape:")
    print(f"    Running requests:            {_fmt_int(_gauge_value(end, 'sglang:num_running_reqs', metrics_model))}")
    print(f"    Queued requests:             {_fmt_int(_gauge_value(end, 'sglang:num_queue_reqs', metrics_model))}")
    print(f"    Paused requests:             {_fmt_int(_gauge_value(end, 'sglang:num_paused_reqs', metrics_model))}")
    print(f"    Retracted requests:          {_fmt_int(_gauge_value(end, 'sglang:num_retracted_reqs', metrics_model))}")
    print(f"    Token usage:                 {_fmt_percent(_gauge_value(end, 'sglang:token_usage', metrics_model))}")
    print(f"    Used tokens:                 {_fmt_int(_gauge_value(end, 'sglang:num_used_tokens', metrics_model))}")
    print(f"    Max total tokens:            {_fmt_int(_gauge_value(end, 'sglang:max_total_num_tokens', metrics_model))}")
