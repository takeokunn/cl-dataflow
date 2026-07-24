(("graph-export/dot-basic" . "\"digraph flow {
  \\\"a\\\";
  \\\"b\\\";
  \\\"c\\\";
  \\\"a\\\" -> \\\"b\\\" [label=\\\"value -> value\\\"];
  \\\"a\\\" -> \\\"c\\\" [label=\\\"value -> value\\\"];
}
\"")
 ("graph-export/mermaid-basic" . "\"flowchart LR
  n0[\\\"a\\\"]
  n1[\\\"b\\\"]
  n2[\\\"c\\\"]
  n0 -->|value -> value| n1
  n0 -->|value -> value| n2
\""))
