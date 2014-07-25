xquery version "1.0-ml";
import module namespace cfg = "http://mr-cfg" at "/src/config/settings.xqy";
declare namespace xh = "xdmp:http";

(: get all news items that don't have a "screenshot-saved" collection :)
for $i in cts:search(/news-item, cts:and-not-query(
    cts:collection-query("news-item")
    ,
    cts:collection-query("screenshot-saved")
    )
)

    let $_ := xdmp:log("GET-SCREENSHOTS.XQY -- " || xdmp:node-uri($i))
    return
        if (not(doc-available(replace(xdmp:node-uri($i), "item.xml", "screenshot.png"))))
        then
            xdmp:invoke("/src/tasks/take-one-screenshot.xqy", 
                (
                    map:entry("item", $i)
                )
            )
        else ()
