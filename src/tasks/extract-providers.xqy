xquery version "1.0-ml";

for $item in collection("news-item")
    return xdmp:invoke("/src/tasks/record-one-provider.xqy", map:entry("item", $item))
    