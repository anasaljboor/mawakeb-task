import json
import sys
import urllib.request

ROOTS = [
    "kubernetes",
    "workflow-aggregator",
    "git",
    "configuration-as-code",
    "job-dsl",
    "credentials-binding",
    "lockable-resources",
    "junit",
    "timestamper",
    "pipeline-utility-steps",
]


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: resolve-jenkins-plugins.py <jenkins-core-version> <output-file>")
    core, out = sys.argv[1], sys.argv[2]

    url = f"https://updates.jenkins.io/update-center.actual.json?version={core}"
    with urllib.request.urlopen(url, timeout=60) as r:
        plugins = json.load(r)["plugins"]

    resolved = {}
    stack = list(ROOTS)
    while stack:
        name = stack.pop()
        if name in resolved:
            continue
        if name not in plugins:
            sys.exit(f"plugin not available for core {core}: {name}")
        resolved[name] = plugins[name]["version"]
        stack += [d["name"] for d in plugins[name].get("dependencies", []) if not d.get("optional")]

    with open(out, "w") as f:
        f.write("".join(f"{n}:{resolved[n]}\n" for n in sorted(resolved)))
    print(f"{len(resolved)} plugins for Jenkins {core} -> {out}")


if __name__ == "__main__":
    main()
