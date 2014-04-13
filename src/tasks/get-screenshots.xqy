xquery version "1.0-ml";
import module namespace cfg = "http://mr-cfg" at "/src/config/settings.xqy";
declare namespace xh = "xdmp:http";

for $i in cts:search(/news-item, cts:and-not-query(
    cts:collection-query("news-item")
    ,
    cts:collection-query("screenshot-saved")
    )
)
   
    let $doc-url := xdmp:node-uri($i)
    
    (: make double-sure not to re-take snapshots :)
    let $has-screenshot := ("screenshot-saved" = xdmp:document-get-collections(xdmp:node-uri($i)))
    
    return 
        if (not($has-screenshot))
        then
            xdmp:invoke("/src/tasks/take-one-screenshot.xqy", 
                (
                    map:new(map:entry("path", replace($doc-url, "item.xml", "screenshot.png"))),
                    map:new(map:entry("link", string($i//link))),
                    map:new(map:entry("url", $doc-url))        
                )
            )
        else ()
