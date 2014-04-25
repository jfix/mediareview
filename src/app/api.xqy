xquery version "1.0-ml";

(:
    This module exposes the API.
    It uses RXQ as the routing mechanism.
    Look at the annotations for each function to understand what they
    are supposed to do.
    
 :)

module namespace api = "http://mr-api";
import module namespace rxq="﻿http://exquery.org/ns/restxq" at "/lib/xquery/rxq.xqy";
import module namespace json="http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";
import module namespace u = "http://mr-utils" at "/lib/xquery/utils.xqm";

(:~
 : Return a JSON array containing provider information.
 : TODO: add number of news-items per provider.
 :)
declare
    %rxq:path('/api/providers')
    %rxq:GET
    %rxq:produces('application/json')
function api:providers()
{
    (
        xdmp:set-response-code(200, "OK"), 
        xdmp:to-json( 
            for $p in collection("provider")/provider
                let $n := string($p/name)
                let $l := string($p/link)
                let $i := data($p/@id)
                return 
                        map:new((
                            map:entry("id", $i), 
                            map:entry("name", $n), 
                            map:entry("link", $l)
                        ))
        ) 
    )
};

(:~
 : Return a JSON array containing language codes and the number of times 
 : they occur in the DB.
 :)
declare
    %rxq:path('/api/languages')
    %rxq:GET
    %rxq:produces('application/json')
function api:languages()
{
    let $languages := cts:element-values(xs:QName("language"), (), "frequency-order")
    let $array := json:array()
    let $_ := for $l in $languages return json:array-push($array, ($l, cts:frequency($l)))
    return
        (
            xdmp:set-response-code(200, "OK"), 
            xdmp:to-json($array)
        )
};

(:~
 : Provide a JSON array containing news story count per day. Number of 
 : past days is configurable. Returns JSON array
 :)
declare
    %rxq:path('/api/frequency')
    %rxq:GET
    %rxq:produces('application/json')
function api:frequency()
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

declare
    %rxq:path('/api/status')
    %rxq:GET
function api:status(
) as item()
{
    let $total-number-items := count(collection("news-item"))
    let $items-missing-screenshot := count(cts:search(/news-item, cts:and-not-query(cts:collection-query("news-item"), cts:collection-query("screenshot-saved"))))
    let $items-missing-language := count(cts:search(/news-item, cts:and-not-query(cts:collection-query("news-item"), cts:collection-query("language-detected"))))
    
    let $general := map:new((
            map:entry("time-stamp", current-dateTime()),
            map:entry("items-total", $total-number-items),
            map:entry("items-missing-screenshot", $items-missing-screenshot),
            map:entry("items-missing-language", $items-missing-language)
        ))
    let $screenshots := map:new((
        (: add 
            - last run timestamp
            - status (success/error)
            - number of items handled in last run
        :)
    ))

    let $languages := map:new((
        (: add 
            language-detection
            - last run timestamp
            - status (success/error)
            - # of items handled
            
        :)
    ))

    let $news-import := map:new((
        (: add 
            google-rss
            - status (success/error)
            - last run
            - number of items inserted/ignored
            oecd rss
            - status (success/error)
            - last run
            - number of items inserted/ignored
            ....
            - status (success/error)
            - last run
            - number of items inserted/ignored
        :)
    ))


    return
        (xdmp:set-response-code(200, "OK"), 
         xdmp:to-json(map:new((
            map:entry("general", $general),
            map:entry("screenshots", $screenshots),
            map:entry("newsitems", $news-import),
            map:entry("languages", $languages)
         )))
        )
};

(:~
 : Returns XML or JSON document of news-item identified by $id
 :
 :)
declare
    %rxq:path('/api/news-items/([a-f0-9]+)\.(xml|json|html)')
    %rxq:GET
function api:news-item(
    $id as xs:string,
    $ext as xs:string
) as item()
{
    let $res := cts:search(/news-item, 
                    cts:and-query((
                        cts:collection-query("id:" || $id),
                        cts:collection-query("news-item")
                    ))
                )
    let $config := json:config("custom")
    let $_ := map:put($config, "ignore-attribute-names", ("query", "guid", "confidence", "time"))
    let $_ := map:put($config, "ignore-element-names", ("full-html", "date", "normalized-date"))

    return
    (
        if (not($res))
        then
            (
                xdmp:set-response-code(404, "Not found"),
                "Not found - check item id"
            )
        else 
            (
                xdmp:set-response-code(200, "OK"),
        
                (: === HTML ==== :)

                switch (lower-case($ext))
                case "html" return
                    (
                        xdmp:set-response-content-type("text/html"),
                        xdmp:xslt-invoke("/lib/xslt/item2html.xsl", $res)
                    )
                
                (: === XML ==== :)
                case "xml" return
                    (
                        xdmp:set-response-content-type("text/xml"),
                        $res
                    )
                    
                (: === JSON ==== :)
                (: case "json" :)
                default return
                    (
                        xdmp:set-response-content-type("application/json"),
                     
                        let $j := json:transform-to-json-object($res, $config)
                        let $nm := map:get($j, "news-item")
                        let $pm := map:new()
                        
                        let $provider-id := u:create-provider-id($res)
                        
                        let $_ := map:put($pm, "id", $provider-id)
                        let $_ := map:put($pm, "name", map:get($nm, "provider"))
                        let $_ := map:put($nm, "provider", $pm)
                        let $_ := map:put($nm, "time", data($res/normalized-date/@time))
                        let $_ := map:put($nm, "date", string($res/normalized-date))
                        let $_ := map:put($nm, "screenshot", "/api/news-items/" || $res/@id || "/screenshot")
                        
                        return xdmp:to-json($j)
                    )
            )
    )
};

(:~
 : Returns screenshot of news-item identified by $id, or placeholder image otherwise
 : param $id string identifying the news item
 : return 
 :)
declare
    %rxq:path('/api/news-items/([a-f0-9]+)/screenshot')
    %rxq:GET
    %rxq:produces('image/png')
function api:screenshot(
    $id as xs:string
) as item()
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
    <body>
        <p>{
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
                ))
            } 
            not yet language-detected
        </p>
        <hr/>
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
