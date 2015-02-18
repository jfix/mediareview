xquery version "1.0-ml";

(:
    This module exposes the API.
    It uses RXQ as the routing mechanism.
    Look at the annotations for each function to understand what they
    are supposed to do.
    
 :)

module namespace api = "http://mr-api";
import module namespace json="http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";
import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-doc-2007-01.xqy";
import module namespace u = "http://mr-utils" at "/src/lib/xquery/utils.xqm";
import module namespace rxq = "http://exquery.org/ns/restxq" at "/src/lib/xquery/rxq.xqy";

(:~
 : Return the last XXX (currently 100) events in a JSON array
 :)
declare
    %rxq:path('/api/events')
    %rxq:GET
    %rxq:produces('application/json')
function api:events(

)
{
    let $number-of-events := 100
    let $events := (collection("event")/event)[1 to $number-of-events]
    
    return
    (
        xdmp:set-response-code(200, "OK")
        ,
        (: no events, return empty map :)
        if (count($events) <= 0)    
        then
            xdmp:to-json(map:new(()))
        (: else return first $number-of-events events :)
        else
            xdmp:to-json( 
                for $e in $events
                    let $id as xs:string := $e/@id
                    let $dateTime as xs:dateTime := $e/when
                    let $message as xs:string := $e/message
                    let $result as xs:string := $e/what/result
                    let $newsitem-id as xs:string := $e/what/newsitem-id
                    return 
                            map:new((
                                map:entry("id", $id), 
                                map:entry("dateTime", $dateTime), 
                                map:entry("message", $message),
                                map:entry("newsitem-id", $newsitem-id),
                                map:entry("result", $result)
                            ))
            ) 
    )
};

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
    let $providers := collection("provider")/provider
    
    return
    (
        xdmp:set-response-code(200, "OK")
        , 
        xdmp:to-json(
            if (count($providers) <= 0)
            then
                map:new(())
            else
                for $p in $providers
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
    let $items-missing-content := count(cts:search(/news-item, cts:and-not-query(cts:collection-query("news-item"), cts:collection-query("content-retrieved"))))
    
    let $general := map:new((
            map:entry("time-stamp", current-dateTime()),
            map:entry("items-total", $total-number-items),
            map:entry("items-missing-screenshot", $items-missing-screenshot),
            map:entry("items-missing-language", $items-missing-language),
            map:entry("items-missing-content", $items-missing-content)
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
 : Returns XML or JSON document of a provider as identified by $id.
 : @TODO: add URLs of news items for a provider
 : @param id as xs:string
 : @param format as xs:string
 : @return item in XML or JSON
 :)
declare
    %rxq:path('/api/providers/([a-f0-9]+)\.?(xml|json)?')
    %rxq:GET
function api:provider(
    $id as xs:string,
    $ext as xs:string?
) as item()
{
    let $provider := collection("id:" || $id)/provider
    let $format := if ($ext) then $ext else "json"

    return
    (
        if (not($provider))
        then
            (
                xdmp:set-response-code(404, "Not found"),
                "Not found - check item id"
            )
        else 
            (
                xdmp:set-response-code(200, "OK"),
                u:set-response-header($format),
                u:convert-provider($provider, $format)
            )
    )
};

(:~
 : Returns XML, HTML or JSON document of news-item as identified by $id.
 :
 :
 :)
declare
    %rxq:path('/api/news-items/([a-f0-9]+)\.?(xml|json|html)?')
    %rxq:GET
function api:news-item(
    $id as xs:string,
    $ext as xs:string?
) as item()
{
    let $res := cts:search(/news-item, 
                    cts:and-query((
                        cts:collection-query("id:" || $id),
                        cts:collection-query("news-item")
                    ))
                )
    let $format := if ($ext) then $ext else "json"
    
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
                u:set-response-header($format),
                u:convert-news-item($res, $format)
            )
    )
};

declare
    %rxq:path('/api/news-items/([a-f0-9]+)/content')
    %rxq:GET
    %rxq:produces('text/html')
function api:content(
    $id as xs:string
) as item()
{
   try {
        (
            xdmp:set-response-code(200, "OK"),
            document(replace(xdmp:node-uri(collection("id:"||$id)[1]), "item.xml", "contents.html"))
        )
    } catch($e) {
        (
            xdmp:set-response-code(404, "Not found"),
            <html>
            <body>
                here should be content but there isn't any yet<br/>
                you can attempt to force retrieval by clicking this button:<br/>
                ...
            </body>
            </html>
        )
    }   
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
 : Returns a list of news items within a given time period.
 : This time period can be defined using a certain number of parameters:
 : - date=yyyy-mm-dd: returns news items for this specific date
 : - since=n: returns news items between today and today - n days
 : - from=yyyy-mm-dd, to=yyyy-mm-dd: returns items between (inclusive) these two dates
 :
 :
 :
 :)
declare
    %rxq:path('/api/news-items/?')
    %rxq:GET
function api:news-items(
)
{
    (: acceptable query parameters:
        - date=yyyy-mm-dd                   [default: current-date]
        - since=duration-as-integer-days    [default: 1]
        - from=yyyy-mm-dd and to=yyyy-mm-dd [defaults: from=current-date, to=current-date, equivalent of date]
    :)
    let $format := xdmp:get-request-field("format", "xml")
    
    let $specific-date := xs:date(xdmp:get-request-field("date"))
    
    let $since-param := xdmp:get-request-field("since", "0")
    let $since := current-date() - xs:dayTimeDuration("P" || 
        (if (functx:is-a-number($since-param)) then $since-param else 0) 
        || "D")
    
    (: === start date === :)
    let $from as xs:date := 
        if ($specific-date instance of xs:date) 
        then 
            $specific-date
        else
            if ($since instance of xs:date)
            then
                $since
            else
                (: default: yesterday :)
                xs:date(xdmp:get-request-field("from", xs:string(current-date() - xs:dayTimeDuration("P1D"))))
    
    (: === end date === :)
    let $to as xs:date := 
        if ($specific-date instance of xs:date)
        then
            $specific-date
        else 
            xs:date(xdmp:get-request-field("to", xs:string(current-date()) ))
    
    let $queries := (
        cts:element-range-query(xs:QName("normalized-date"), ">=", $from),
        cts:element-range-query(xs:QName("normalized-date"), "<=", $to)
    )

    let $items := cts:search(collection("news-item")/news-item, cts:and-query($queries))
(:    let $_ := xdmp:log("ITEMS: " || count($items)):)
    
    return
        (
            xdmp:set-response-code(200, "OK"),
            xdmp:set-response-encoding("UTF-8"),
            u:set-response-header($format),
            u:convert-news-items(
                $items, 
                map:new((
                    map:entry("format", $format),
                    map:entry("from", $from), 
                    map:entry("to", $to), 
                    map:entry("count", count($items))
                ))
            )
        )
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
    <head>
        <title>mr-test</title>
    </head>
    <body>
        <p>{
            count(collection("news-item"))
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
            
            - { count(collection("content-retrieved")) }
            
            content items
        </p>
        <hr/>
        <div>
            <ul>{
            for $item in (collection("news-item")//news-item)[1 to 1000]
            order by xs:date($item/normalized-date) descending, xs:time($item/normalized-date/@time) descending
            return 
                <li>
                    {$item/date}: 
                    
                    {if ($item/language) then $item/language[1] || " - " else ()}
                    
                    <a href="{$item/link}">{ $item/title || " - " || $item/provider}</a>
                    -
                    {if (("screenshot-saved" = xdmp:document-get-collections(xdmp:node-uri($item))))
                     then
                        <a href="{"/api/news-items/" || $item/@id || "/screenshot"}">screenshot</a>
                     else 
                        xdmp:node-uri($item)
                    }
                    -
                    {if (("content-retrieved" = xdmp:document-get-collections(xdmp:node-uri($item))))
                     then
                        <a href="{"/api/news-items/" || $item/@id || "/content"}">content</a>
                     else 
                        "[no content]"
                    }
                </li>
            }</ul>
        </div>
    </body>
</html>
};
