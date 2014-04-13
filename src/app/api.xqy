xquery version "1.0-ml";
module namespace api = "http://mr-api";

import module namespace rxq="﻿http://exquery.org/ns/restxq" at "/lib/xquery/rxq.xqy";

(:~
 : Provide a JSON array containing news story count per day. Number of past days is configurable.
 : Returns JSON array
 :)
declare
    %rxq:path('/api/news-items')
    %rxq:GET
    %rxq:produces('application/json')
function api:news-items()
{
    (: restrict output to the last X days, default is last 7 days :)
    let $since := xs:integer(xdmp:get-request-field("since", "7"))
    let $query := cts:element-range-query(
        xs:QName("normalized-date"), 
        ">=", 
        (current-date() - (xs:dayTimeDuration('P1D') * (if ($since >= 365) then 364 else $since - 1)))
    )
    (: get all unique normalized-dates from range index :)
    let $dates := cts:element-values(xs:QName("normalized-date"), (), (), $query)
    let $m :=  $dates ! map:new((map:entry(xs:string(.), cts:frequency(.))))
    
    let $min-date := min($dates), $max-date := max($dates)
    (: for the case of dates without news stories, we need to create padding :)
    let $padding-dates := (0 to days-from-duration($max-date - $min-date))  ! ($min-date + . * xs:dayTimeDuration('P1D'))
    
    let $full-array :=  json:array()
    
    let $_ := for $p in $padding-dates
        let $string-date := xs:string($p)
        order by $p descending
        return
            if ($string-date = map:keys($m))
            then
                json:array-push($full-array, ($string-date, map:get($m, $string-date)))
            else
                json:array-push($full-array, ($string-date, 0))

    return (xdmp:set-response-code(200, "OK"), xdmp:to-json($full-array))    
};


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
    (
    xdmp:set-response-code(200, "OK"),
    collection("id:"||$id)[1]
    )
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
        (
        xdmp:set-response-code(200, "OK"),
        document(replace(xdmp:node-uri(collection("id:"||$id)[1]), "item.xml", "screenshot.png"))
        )
    } catch($e) {
        (
        xdmp:set-response-code(404, "Not found"),
        xdmp:http-get("http://placehold.it/800x400&amp;text=screenshot+not+yet+available")[2]
        )
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
xdmp:set-response-code(200, "OK"),
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
            ))} 
        missing screenshot image
        
        - {count(cts:search(/news-item, cts:and-not-query(
            cts:collection-query("news-item")
            ,
            cts:collection-query("language-detected")
            )
            ))} 
        not yet language-detected
</p>
        <div>
            <ul>{
            for $item in collection("news-item")//news-item
            order by xs:date($item/normalized-date) descending, xs:time($item/normalized-date/@time) descending
            return 
                <li>
                    {$item/date}: 
                    
                    {if ($item/language) then $item/language || " - " else ()}
                    
                    <a href="{$item/link}">{ $item/title || " - " || $item/provider}</a>
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
