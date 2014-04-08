xquery version "1.0-ml";
(:import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-doc-2007-01.xqy";:)
(:declare namespace html = "http://www.w3.org/1999/xhtml";:)
declare option xdmp:output "media-type=text/html";

<html>
    <head></head>
    <body><p>{
        count(collection("news-item")//news-item)
        } items
        
        - {count(cts:search(/news-item, cts:and-not-query(
cts:collection-query("news-item")
,
cts:collection-query("screenshot-saved")
)
))} missing screenshot image</p>
        <div>
            <ul>{
            for $item in collection("news-item")//news-item
            order by $item/normalized-date descending
            return 
                <li>
                    {$item/date}: <a href="{$item//link}">{ $item/title || " - " || $item/provider}</a>
                    -
                    {if (("screenshot-saved" = xdmp:document-get-collections(xdmp:node-uri($item))))
                     then
                        <a href="{replace(xdmp:node-uri($item), "item.xml", "screenshot.png")}">screenshot</a>
                     else 
                        xdmp:node-uri($item)
                    }
                </li>
            }</ul>
        </div>
    </body>
</html>
