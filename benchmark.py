import time
import asyncio
import statistics
import random
import uuid
import argparse
import sys
from openai import AsyncOpenAI
from dataclasses import dataclass

def parse_args():
    parser = argparse.ArgumentParser(
        description="LLM Throughput Benchmark",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Example usage:
  python bench.py --model glm-4.7-fp8
  python bench.py --model glm-4.5-air --concurrency 500 --num-prompts 500
  python bench.py --model glm-4.7-fp8 --api-key MY_REAL_KEY --base-url http://remote:8000/v1
        """
    )
    
    # Required arguments
    required = parser.add_argument_group('required arguments')
    required.add_argument("--model", type=str, required=True,
                         help="Model name (e.g., glm-4.7-fp8, glm-4.5-air)")
    
    # Optional arguments with defaults
    optional = parser.add_argument_group('optional arguments (with defaults)')
    optional.add_argument("--api-key", type=str, default="YOUR_API_KEY",
                         help="API key (default: YOUR_API_KEY)")
    optional.add_argument("--concurrency", type=int, default=100,
                         help="Number of concurrent requests (default: 100)")
    optional.add_argument("--num-prompts", type=int, default=100,
                         help="Total number of prompts to run (default: 100)")
    optional.add_argument("--base-url", type=str, default="http://localhost:8000/v1",
                         help="API base URL (default: http://localhost:8000/v1)")
    optional.add_argument("--min-input", type=int, default=1000,
                         help="Minimum input tokens (default: 1000)")
    optional.add_argument("--max-input", type=int, default=8000,
                         help="Maximum input tokens (default: 8000)")
    optional.add_argument("--min-output", type=int, default=256,
                         help="Minimum output tokens (default: 256)")
    optional.add_argument("--max-output", type=int, default=1024,
                         help="Maximum output tokens (default: 1024)")
    optional.add_argument("--timeout", type=int, default=600,
                         help="Timeout per request in seconds (default: 600)")
    optional.add_argument("--warmup", type=int, default=3,
                         help="Number of warmup requests (default: 3)")
    optional.add_argument("--no-ignore-eos", action="store_true",
                         help="Don't force full output length (default: force full output)")
    
    args = parser.parse_args()
    
    # Validation
    errors = []
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
    
    if errors:
        print("ERROR: Invalid arguments:")
        for e in errors:
            print(f"  - {e}")
        sys.exit(1)
    
    return args

# Parse arguments first
args = parse_args()

# Configuration from args
BASE_URL = args.base_url
API_KEY = args.api_key
MODEL = args.model
NUM_PROMPTS = args.num_prompts
CONCURRENCY = args.concurrency
TIMEOUT_PER_REQUEST = args.timeout
WARMUP_REQUESTS = args.warmup
MIN_INPUT_TOKENS = args.min_input
MAX_INPUT_TOKENS = args.max_input
MIN_OUTPUT_TOKENS = args.min_output
MAX_OUTPUT_TOKENS = args.max_output
IGNORE_EOS = not args.no_ignore_eos

client = AsyncOpenAI(
    base_url=BASE_URL,
    api_key=API_KEY,
    timeout=TIMEOUT_PER_REQUEST,
    max_retries=0,
)

TASK_TEMPLATES = [
    "Analyze the following document and provide a detailed summary with key insights:\n\n{content}",
    "You are a coding assistant. Review this code and suggest improvements, explain bugs, and provide refactored version:\n\n{content}",
    "Act as a research analyst. Based on the following information, provide a comprehensive analysis:\n\n{content}",
    "You are a technical writer. Create detailed documentation for the following:\n\n{content}",
    "As a data analyst, interpret the following data and provide insights and recommendations:\n\n{content}",
    "You are a business consultant. Analyze this scenario and provide strategic recommendations:\n\n{content}",
    "Act as an expert tutor. Explain the following concepts in detail with examples:\n\n{content}",
    "You are a creative writer. Expand on the following premise with rich detail:\n\n{content}",
    "As a legal advisor, review the following and provide a detailed analysis:\n\n{content}",
    "You are a product manager. Analyze these requirements and create a detailed specification:\n\n{content}",
]

TOPICS = [
    "distributed systems architecture", "machine learning pipelines", "kubernetes orchestration",
    "database optimization", "API design patterns", "microservices communication",
    "cloud infrastructure", "security best practices", "performance tuning",
    "data engineering", "CI/CD pipelines", "monitoring and observability",
    "load balancing strategies", "caching mechanisms", "message queues",
    "authentication systems", "rate limiting", "fault tolerance",
    "container networking", "service mesh", "event-driven architecture",
    "GraphQL vs REST", "serverless computing", "edge computing",
]

CODE_SNIPPETS = [
    "def process_data(items):\n    results = []\n    for item in items:\n        if item.valid:\n            results.append(transform(item))\n    return results",
    "async def fetch_all(urls):\n    async with aiohttp.ClientSession() as session:\n        tasks = [fetch(session, url) for url in urls]\n        return await asyncio.gather(*tasks)",
    "class DataPipeline:\n    def __init__(self, source):\n        self.source = source\n        self.transforms = []\n    def add_transform(self, fn):\n        self.transforms.append(fn)\n    def execute(self):\n        data = self.source.read()\n        for t in self.transforms:\n            data = t(data)\n        return data",
]

@dataclass
class RequestResult:
    request_id: int
    prompt_tokens: int = 0
    completion_tokens: int = 0
    total_time: float = 0
    ttft: float = 0
    input_len: int = 0
    output_len: int = 0
    success: bool = True
    error: str = None

def generate_random_content(target_chars: int) -> str:
    """Generate random but coherent-looking content."""
    paragraphs = []
    current_len = 0
    
    while current_len < target_chars:
        content_type = random.choice(["prose", "technical", "data", "code"])
        
        if content_type == "prose":
            topic = random.choice(TOPICS)
            sentences = [
                f"The concept of {topic} is fundamental to modern systems.",
                f"When implementing {topic}, one must consider various factors.",
                f"Best practices for {topic} include careful planning and testing.",
                f"Many organizations struggle with {topic} due to complexity.",
                f"Recent advances in {topic} have transformed the industry.",
                f"Understanding {topic} requires knowledge of underlying principles.",
                f"The relationship between {topic} and system performance is crucial.",
                f"Experts recommend iterative approaches to {topic} implementation.",
            ]
            para = " ".join(random.sample(sentences, k=random.randint(3, 6)))
            
        elif content_type == "technical":
            para = f"""
            Configuration for {random.choice(TOPICS)}:
            - Parameter alpha: {random.uniform(0.1, 1.0):.4f}
            - Parameter beta: {random.randint(100, 10000)}
            - Threshold: {random.uniform(0.5, 0.99):.3f}
            - Max iterations: {random.randint(50, 500)}
            - Batch size: {random.choice([16, 32, 64, 128, 256])}
            - Learning rate: {random.uniform(0.0001, 0.01):.6f}
            - Timeout: {random.randint(30, 300)} seconds
            - Retry count: {random.randint(1, 5)}
            """
            
        elif content_type == "data":
            rows = []
            for i in range(random.randint(5, 15)):
                row = f"Record {i}: value={random.uniform(0, 1000):.2f}, count={random.randint(1, 1000)}, status={'active' if random.random() > 0.3 else 'inactive'}"
                rows.append(row)
            para = "Data sample:\n" + "\n".join(rows)
            
        else:
            para = "Code snippet:\n```\n" + random.choice(CODE_SNIPPETS) + "\n```"
        
        paragraphs.append(para)
        current_len = sum(len(p) for p in paragraphs)
    
    return "\n\n".join(paragraphs)

def generate_unique_prompt(target_tokens: int) -> str:
    """Generate a completely unique prompt for each request."""
    unique_prefix = f"[Request ID: {uuid.uuid4()}] [Timestamp: {time.time_ns()}] [Random: {random.random()}]\n\n"
    
    template = random.choice(TASK_TEMPLATES)
    target_chars = target_tokens * 4
    content = generate_random_content(target_chars - len(template) - len(unique_prefix))
    return unique_prefix + template.format(content=content)

async def run_single_request_streaming(
    request_id: int,
    progress: dict
) -> RequestResult:
    """Run request with streaming to measure TTFT."""
    
    input_len = random.randint(MIN_INPUT_TOKENS, MAX_INPUT_TOKENS)
    output_len = random.randint(MIN_OUTPUT_TOKENS, MAX_OUTPUT_TOKENS)
    prompt = generate_unique_prompt(input_len)
    
    start = time.perf_counter()
    ttft = 0
    completion_tokens = 0
    prompt_tokens = 0
    
    try:
        request_params = {
            "model": MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": output_len,
            "temperature": random.uniform(0.5, 0.9),
            "stream": True,
            "stream_options": {"include_usage": True},
        }
        
        if IGNORE_EOS:
            request_params["extra_body"] = {"ignore_eos": True}
        
        stream = await client.chat.completions.create(**request_params)
        
        first_token = True
        async for chunk in stream:
            if first_token and chunk.choices and chunk.choices[0].delta.content:
                ttft = time.perf_counter() - start
                first_token = False
            if chunk.usage:
                prompt_tokens = chunk.usage.prompt_tokens
                completion_tokens = chunk.usage.completion_tokens
        
        end = time.perf_counter()
        
        result = RequestResult(
            request_id=request_id,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            total_time=end - start,
            ttft=ttft,
            input_len=input_len,
            output_len=output_len,
        )
        
    except asyncio.TimeoutError:
        result = RequestResult(request_id=request_id, success=False, error="timeout", input_len=input_len, output_len=output_len)
    except Exception as e:
        result = RequestResult(request_id=request_id, success=False, error=str(e)[:100], input_len=input_len, output_len=output_len)
    
    progress["completed"] += 1
    if not result.success:
        progress["failed"] += 1
    
    elapsed = time.perf_counter() - progress["start_time"]
    rate = progress["completed"] / elapsed if elapsed > 0 else 0
    print(f"\rProgress: {progress['completed']}/{NUM_PROMPTS} | Failed: {progress['failed']} | Rate: {rate:.2f} req/s", end="", flush=True)
    
    return result

async def warmup():
    """Warmup requests to stabilize performance."""
    print(f"Warming up with {WARMUP_REQUESTS} requests...")
    for i in range(WARMUP_REQUESTS):
        try:
            await client.chat.completions.create(
                model=MODEL,
                messages=[{"role": "user", "content": f"Warmup request {uuid.uuid4()}. Say hello."}],
                max_tokens=50,
            )
            print(f"\rWarmup: {i+1}/{WARMUP_REQUESTS}", end="", flush=True)
        except Exception as e:
            print(f"\rWarmup {i+1} failed: {e}", end="", flush=True)
    print(" Done!")

async def run_benchmark():
    random.seed()
    
    print("\n" + "="*60)
    print("NOTE: For accurate benchmarks, start server with:")
    print("  SGLang: --disable-radix-cache")
    print("  vLLM:   --disable-prefix-caching")
    print("="*60 + "\n")
    
    await warmup()
    
    progress = {"completed": 0, "failed": 0, "start_time": time.perf_counter()}
    
    print(f"\n{'='*60}")
    print(f"BENCHMARK CONFIG")
    print(f"{'='*60}")
    print(f"Model:               {MODEL}")
    print(f"Base URL:            {BASE_URL}")
    print(f"Total requests:      {NUM_PROMPTS}")
    print(f"Concurrency:         {CONCURRENCY} (simulating {CONCURRENCY} agents)")
    print(f"Input tokens:        {MIN_INPUT_TOKENS} - {MAX_INPUT_TOKENS} (random)")
    print(f"Output tokens:       {MIN_OUTPUT_TOKENS} - {MAX_OUTPUT_TOKENS} (random)")
    print(f"Timeout per request: {TIMEOUT_PER_REQUEST}s")
    print(f"ignore_eos:          {IGNORE_EOS} {'(forces full output)' if IGNORE_EOS else '(natural stopping)'}")
    print(f"{'='*60}\n")
    
    semaphore = asyncio.Semaphore(CONCURRENCY)
    
    async def bounded_request(i):
        async with semaphore:
            return await run_single_request_streaming(i, progress)
    
    overall_start = time.perf_counter()
    results = await asyncio.gather(*[bounded_request(i) for i in range(NUM_PROMPTS)])
    overall_end = time.perf_counter()
    
    print("\n")
    
    successful = [r for r in results if r.success]
    failed = [r for r in results if not r.success]
    
    if not successful:
        print("\nAll requests failed!")
        for r in failed[:10]:
            print(f"  Request {r.request_id}: {r.error}")
        return
    
    total_prompt_tokens = sum(r.prompt_tokens for r in successful)
    total_completion_tokens = sum(r.completion_tokens for r in successful)
    total_tokens = total_prompt_tokens + total_completion_tokens
    total_wall_time = overall_end - overall_start
    
    latencies = [r.total_time for r in successful]
    ttfts = [r.ttft for r in successful if r.ttft > 0]
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
    
    print(f"{'='*60}")
    print(f"RESULTS - {MODEL}")
    print(f"{'='*60}")
    print(f"Successful requests:     {len(successful)}/{NUM_PROMPTS}")
    print(f"Failed requests:         {len(failed)}")
    print(f"Avg input tokens (cfg):  {avg_input:.0f}")
    print(f"Avg input tokens (actual): {actual_avg_input:.0f}")
    print(f"Avg output tokens (cfg): {avg_output:.0f}")
    print(f"Avg output tokens (actual): {actual_avg_output:.0f}")
    print(f"Total prompt tokens:     {total_prompt_tokens:,}")
    print(f"Total completion tokens: {total_completion_tokens:,}")
    print(f"Total wall time:         {total_wall_time:.2f}s")
    
    print(f"\nTHROUGHPUT:")
    print(f"  Requests/sec:          {len(successful) / total_wall_time:.2f}")
    print(f"  Output tokens/sec:     {total_completion_tokens / total_wall_time:.2f}")
    print(f"  Total tokens/sec:      {total_tokens / total_wall_time:.2f}")
    
    if ttfts:
        print(f"\nTIME TO FIRST TOKEN (TTFT):")
        print(f"  Mean:                  {statistics.mean(ttfts)*1000:.0f}ms")
        print(f"  Median:                {statistics.median(ttfts)*1000:.0f}ms")
        print(f"  P95:                   {percentile(ttfts, 0.95)*1000:.0f}ms")
        print(f"  P99:                   {percentile(ttfts, 0.99)*1000:.0f}ms")
    
    print(f"\nEND-TO-END LATENCY:")
    print(f"  Mean:                  {statistics.mean(latencies):.2f}s")
    print(f"  Median:                {statistics.median(latencies):.2f}s")
    print(f"  P95:                   {percentile(latencies, 0.95):.2f}s")
    print(f"  P99:                   {percentile(latencies, 0.99):.2f}s")
    
    print(f"\nPER-REQUEST OUTPUT TPS:")
    print(f"  Mean:                  {statistics.mean(tps_per_request):.2f}")
    print(f"  Std dev:               {statistics.stdev(tps_per_request) if len(tps_per_request) > 1 else 0:.2f}")
    print(f"  Min:                   {min(tps_per_request):.2f}")
    print(f"  Max:                   {max(tps_per_request):.2f}")
    
    if failed:
        print(f"\nFAILED REQUESTS (first 10):")
        for r in failed[:10]:
            print(f"  Request {r.request_id}: {r.error}")
        if len(failed) > 10:
            print(f"  ... and {len(failed) - 10} more")

if __name__ == "__main__":
    asyncio.run(run_benchmark())
