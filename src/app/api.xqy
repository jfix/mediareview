xquery version "1.0-ml";
module namespace api = "http://mr-api";

import module namespace rxq="﻿http://exquery.org/ns/restxq" at "/lib/xquery/rxq.xqy";

(:~
 : Returns XML document of news-item identified by $id
 :
 :)
declare
    %rxq:path('/api/news-items/([a-f0-9]+).xml')
    %rxq:GET
    %rxq:produces('text/xml')
function api:news-item(
    $id as xs:string
) as document-node()
{
    collection("id:"||$id)[1]
};

(:~
 : Returns screenshot of news-item identified by $id, or placeholder image otherwise
 :
 :)
declare
    %rxq:path('/api/news-items/([a-f0-9]+)/screenshot')
    %rxq:GET
    %rxq:produces('image/png')
function api:screenshot(
    $id as xs:string
)
{
    try {
        document(replace(xdmp:node-uri(collection("id:"||$id)[1]), "item.xml", "screenshot.png"))    
    } catch($e) {
        xdmp:http-get("http://placehold.it/800x400&amp;text=screenshot+not+yet+available")[2]
    }            
};

(:~
 : Test page that returns current data, subject to change
 :)
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
            order by xs:dateTime($item/normalized-date) descending
            return 
                <li>
                    {$item/date}: <a href="{$item/link}">{ $item/title || " - " || $item/provider}</a>
                    -
                    {if (("screenshot-saved" = xdmp:document-get-collections(xdmp:node-uri($item))))
                     then
                        <a href="{"/api/news-items/" || $item/@id || "/screenshot"}">screenshot</a>
                     else 
                        xdmp:node-uri($item)
                    }
                </li>
            }</ul>
        </div>
    </body>
</html>
};
