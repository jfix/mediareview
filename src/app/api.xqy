xquery version "1.0-ml";
module namespace api = "http://mr-api";

import module namespace rxq="﻿http://exquery.org/ns/restxq" at "/lib/xquery/rxq.xqy";

declare
    %rxq:path('/test')
    %rxq:GET
    %rxq:produces('text/html')
function api:test-page()
{
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
};
