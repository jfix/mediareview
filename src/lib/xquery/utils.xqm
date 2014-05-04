xquery version "1.0-ml";

module namespace u="http://mr-utils";

import module namespace cfg = "http://mr-cfg" at "../../config/settings.xqy";
import module namespace json="http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";
import module namespace mem="http://xqdev.com/in-mem-update" at "/MarkLogic/appservices/utils/in-mem-update.xqy";
import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-doc-2007-01.xqy";
import module namespace nd="http://marklogic.com/appservices/utils/normalize-dates" at "normalize-dates.xqm";
declare namespace jb = "http://marklogic.com/xdmp/json/basic";

(: to generate an identifier hash using hmac-sha1, I need to provide a secret :)
declare variable $secretkey as xs:string := "not-so-secret-key";

declare variable $default-permissions := (
    xdmp:permission("mr-read-documents-role", "read"),
    xdmp:permission("mr-add-documents-role", "update"),
    xdmp:permission("mr-add-documents-role", "insert")
);
    
(:~
 : Sets the HTTP response header based on a "file extension".
 : To be used (if necessary) before sending back news-item (or 
 : other output).
 : @param $ext xs:string curently understands: xml, html, json
 : @return an empty sequence (but the header gets set)
 :)
declare function u:set-response-header(
    $ext as xs:string
) as empty-sequence()
{
    switch($ext)
    case "html" return xdmp:set-response-content-type("text/html")
    case "json" return xdmp:set-response-content-type("application/json")
    default (:case "xml":)  return xdmp:set-response-content-type("text/xml")
};

declare function u:convert-news-items(
    $items as element(news-item)*,
    $params as map:map
) as item()
{
    let $count := count($items)
    let $_json := json:array()
    let $_ := $params ! json:array-push($_json, .)
    let $format := map:get($params, "format")
    
    return
        switch($format)
        case "json"
            return
                let $_ := $items ! json:array-push($_json, xdmp:from-json(u:convert-news-item(., $format)))
                return xdmp:to-json($_json)
            
        case "html" 
            return <html><head><title>{$count} news item(s)</title></head><body>{
                $items ! u:convert-news-item(., $format)//body/*
            }</body></html>
        
        default 
            return
            <news-items 
                count="{map:get($params, 'count')}" 
                from="{map:get($params, 'from')}" 
                to="{map:get($params, 'to')}">{
                $items ! u:convert-news-item(., $format)
            }</news-items>
};

(:~
 : Takes a news-item XML element as input and returns it 
 : as either XML (unchanged), as HTML or JSON, depending on the 
 : $ext parameter
 : @param $item element(news-item)
 : @param $ext xs:string "xml", "html", "json" ("rdf"?)
 : @return news-item in the specified format
 :)
declare function u:convert-news-item(
    $item as element(news-item),
    $ext as xs:string
) as item()
{
    let $config := json:config("custom")
    let $_ := map:put($config, "ignore-attribute-names", ("id", "query", "guid", "confidence", "time"))
    let $_ := map:put($config, "ignore-element-names", ("full-html", "date", "normalized-date"))

    return
        (: === HTML ==== :)
        switch (lower-case($ext))
        case "html" return
            xdmp:xslt-invoke("/lib/xslt/item2html.xsl", $item)
        
        (: === XML ==== :)
        case "xml" return
            $item
            
        (: === JSON ==== :)
        (: case "json" :)
        default return             
            let $j := json:transform-to-json-object($item, $config)
            let $nm := map:get($j, "news-item")
            let $pm := map:new()
            let $provider-id := u:create-provider-id($item)
            let $_ := map:put($nm, "id", data($item/@id))
            let $_ := map:put($pm, "id", $provider-id)
            let $_ := map:put($pm, "name", map:get($nm, "provider"))
            let $_ := map:put($pm, "url", u:provider-url($item))
            let $_ := map:put($nm, "provider", $pm)
            let $_ := map:put($nm, "time", data($item/normalized-date/@time))
            let $_ := map:put($nm, "date", string($item/normalized-date))
            let $_ := map:put($nm, "screenshot", u:screenshot-url($item))
            
            return xdmp:to-json($nm)
};

(:~
 : Returns an XML element or a JSON object (depending on the supplied
 : format) for a news provider. As a bonus it will also
 :
 :)
declare function u:convert-provider(
    $provider as element(provider),
    $format as xs:string
) as item()
{
    let $config := json:config("custom")
    let $news-item-urls := (collection("news-item")/news-item[provider[./@id=$provider/@id]]/@id) 
        ! u:create-news-item-url(., $format)

    return
        switch(lower-case($format))
        case "xml" 
            return 
                mem:node-insert-child(
                    $provider, 
                    <news-items>{
                        $news-item-urls ! element {"news-item"} { . }
                    }</news-items>
                )
        default 
            return
                let $j := json:transform-to-json-object($provider, $config)
                let $pj := map:get($j, "provider")
                let $_ := map:put($pj, "news-items", $news-item-urls)
                return xdmp:to-json($pj)
};
    
(:~
 : Wrapper for the normalize-datetime function
 : @param xs:string containing a dateTime string in the stupid W3C format that only RSS is using
 : @returns xs:dateTime
 :)
declare function u:normalize-w3c-date(
    $date as xs:string
) as xs:dateTime
{
    let $w3c-date-regex:= "^...,\s+[0-3]?\d\s+\S+\s+\d\d\d\d\s+[0-2]?\d:[0-5]\d:[0-5]\d\s+...$"
    return nd:normalize-datetime($date, $w3c-date-regex)
};


(:~
 : Save the event as a document in the database
 : @param event an XML structure
 : <event id="">
 :  <when>[dateTime]</when>
 :  <!--  -->
 :  <who>rss-bot</who>
 :  <what>
 :      <type>news-retrieval</type>
 :      <retrieved-items>100</retrieved-items>
 :      <inserted-items>3</inserted-items>
 :      <ignored-items>97</ignored-items>
 :  </what>
 :  <message>3 news items have been inserted.</message>
 : </event>
 :
 : @return empty-sequence()
 :)
declare function u:record-event(
    $event as element(event)
) as empty-sequence()
{
    let $id as xs:string := $event/@id
    let $uri := "/events/" || substring($id, 1, 2) || "/" || substring($id, 3) || ".xml"
    let $type := ""
    let $origin as xs:string := $event/who/text()
    
    return
        xdmp:document-insert($uri, $event, 
            xdmp:default-permissions(),
            ("event",
             ("id:" || $id), 
             ("type:" || $type),
             "origin:" || $origin
            )
        )
};

(:~
 : Create an event element with the necessary parameters
 : @param $origin an agent responsible for the event
 : @param $message indicating the what the event is about
 : @param $payload not sure what this could be and how to handle it
 : @return element(event)
 :)
declare function u:create-event(
    $origin as xs:string,
    $message as xs:string,
    $payload as element()*
) as element(event)
{
    let $id := xdmp:hmac-sha1($secretkey, $origin || $message || xdmp:quote($payload) || string(current-dateTime()), "hex")
    return
        <event id="{$id}">
            <when>{current-dateTime()}</when>
            <who>{$origin}</who>
            <what>
            { $payload }
            </what>
            <message>{$message}</message>
        </event>
};

(:~
 : Given a news-item element, return the URL path that points to the
 : screenshot (this is mainly to have this not all over the place)
 : No extension is given, mime-type is always "image/png"
 :)
declare function u:screenshot-url(
    $news-item as element(news-item)
) as xs:string
{
    "/api/news-items/" || $news-item/@id || "/screenshot"
};

(:~
 : Given a news-item element, return the URL path that points to the
 : provider of this news item. No extension in the URL, defaults to 
 : JSON.
 :)
declare function u:provider-url(
    $news-item as element(news-item)
) as xs:string
{
    let $provider-id := u:create-provider-id($news-item)
    return "/api/providers/" || $provider-id
};

(:~
 : Generate an identifier for a news provider based on its domain name
 : @param $news-item element of news
 : @return a string contaning part of the md5 hash
 :)
declare function u:create-provider-id(
    $news-item as element(news-item)
) as xs:string
{
    u:create-provider-id-from-url($news-item/link)
};

declare function u:create-provider-id-from-url(
    $url as xs:string
) as xs:string
{
    let $link := u:extract-host-from-url($url)
    return substring(xdmp:md5($link), 1, 9)
};

declare function u:create-news-item-url(
    $id as xs:string,
    $format as xs:string
) as xs:string
{
    "/api/news-items/" || $id || "." || $format
};

(:~
 : Returns protocol + host from a given URL. This is should help
 : for the news providers to get their "home page" address.
 : 
 : @param $url as xs:string
 : @return xs:string? or empty-sequence()
 :
 :)
declare function u:extract-host-from-url(
    $url as xs:string
) as xs:string?
{
    functx:get-matches($url, "https?://[^/]+")[1]
};

(:~
 : test whether we can still send requests to the detectlanguage.com api
 : or whether we've exhausted the current contingent 
 : (of either the number of daily requests or the limit of bytes that can be sent).
 : returns true or false
 :)
declare function u:detectlanguage-api-requests-remaining(
) as xs:boolean
{
    try {
        let $s := json:transform-from-json(xdmp:http-get($cfg:detectlanguage-status-url)[2])
        return 
            xs:integer($s//jb:daily__requests__limit) > xs:integer($s//jb:requests)
            and
            xs:integer($s//jb:daily__bytes__limit) > xs:integer($s//jb:bytes)
    } catch ($e) {
        (xdmp:sleep(1000), 
         xdmp:log("oops, socket time, wait some and try again!"), 
         u:detectlanguage-api-requests-remaining())
    }
};
