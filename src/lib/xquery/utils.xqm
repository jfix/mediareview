xquery version "1.0-ml";

module namespace u="http://mr-utils";

import module namespace cfg = "http://mr-cfg" at "../../config/settings.xqy";
import module namespace http = "http://http" at "http.xqm";
import module namespace json="http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";
import module namespace mem="http://xqdev.com/in-mem-update" at "/MarkLogic/appservices/utils/in-mem-update.xqy";
import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-doc-2007-01.xqy";
import module namespace nd="http://marklogic.com/appservices/utils/normalize-dates" at "normalize-dates.xqm";
declare namespace jb = "http://marklogic.com/xdmp/json/basic";
declare namespace xh = "xdmp:http";
declare namespace h = "http://www.w3.org/1999/xhtml";

(: to generate an identifier hash using hmac-sha1, I need to provide a secret :)
declare variable $secretkey as xs:string := "not-so-secret-key";

declare variable $api-base as xs:string := "/api";
declare variable $api-base-newsitems as xs:string := $api-base || "/news-items/";
declare variable $api-base-providers as xs:string := $api-base || "/providers/";


declare variable $default-permissions := (
    xdmp:permission("mr-read-documents-role", "read"),
    xdmp:permission("mr-add-documents-role", "update"),
    xdmp:permission("mr-add-documents-role", "insert")
);

(:~
 : These options are used by xdmp:tidy to clean the retrieved HTML. Not sure 
 : it needs to be a global variable.
 :)
declare variable $tidy-options := <options xmlns="xdmp:tidy">
    <new-blocklevel-tags>section, header, time, figure, nav, article</new-blocklevel-tags>
    <bare>yes</bare>
    <clean>yes</clean>
    <hide-comments>yes</hide-comments>
</options>;

declare variable $http-get-options := <options xmlns="xdmp:http">
    <verify-cert>false</verify-cert>
</options>;

(:~
 : Returns the contents of an HTML page if possible.
 : Resolves 301/302 redirects by recursively calling
 : this function with the <location> header
 :
 :)
declare function u:http-get(
    $url as xs:string,
    $options as node()?
) as item()?
{
    let $final-url := u:http-get-url($url)
    return
        if (starts-with($final-url, "http"))
        then
                let $res := xdmp:http-get($final-url, $http-get-options)
                let $code := data($res[1]//xh:code)
                let $_ := xdmp:log("--------- " || $code || ": content retrieval response code: " || $final-url)        
                let $content := xdmp:tidy($res[2], $tidy-options)[2]
                let $content := mem:node-delete($content//h:script | $content//h:style)
                return $content
        else
            ()
};

(:~
 : Returns the "final URL" (i.e. following 301 and 302 redirect requests)
 : @param $url xs:string containing the initial URL
 : @return xs:string containing the final URL, or an error message
 :)
declare function u:http-get-url(
    $url as xs:string
) as xs:string?
{
    let $head-res := try { xdmp:http-head($url, $http-get-options) } catch($e) { xdmp:log("u:http-get-url() - for " || $url || " - error: " || $e//message) }
    let $head-code := $head-res//xh:code
    let $location := $head-res//xh:location
    
    return
        try {
            let $head-location := 
                if ($location)
                then
                    (: Location header should be absolute, but some servers set relative locations,
                       according to a new HTTP spec, that may be acceptable:
                       http://webmasters.stackexchange.com/questions/31274/what-are-the-consequences-for-using-relative-location-headers?answertab=votes#tab-top
                    :)
                    if (not(starts-with($location, 'http')))
                    then
                        u:get-host-from-url($url) || "/" || replace($location, "^/+", "")
                    else
                        $location
                else
                    ()
                        
            return
                switch($head-code)
                    case 200
                        return 
                        (
                            xdmp:log("CASE 200: " || $head-code || " - " || $url), 
                            $url
                        )
                    case 301
                    case 302    
                        return 
                            let $location := $head-res//xh:location
                            let $head-location := 
                                if ($location)
                                then
                                    (: Location header should be absolute, but some servers set relative locations,
                                       according to a new HTTP spec, that may be acceptable:
                                       http://webmasters.stackexchange.com/questions/31274/what-are-the-consequences-for-using-relative-location-headers?answertab=votes#tab-top
                                    :)
                                    if (not(starts-with($location, 'http')))
                                    then
                                        http:get-host-from-url($url) || "/" || replace($location, "^/+", "")
                                    else
                                        $location
                                else
                                    ()
                                return
                                    http:resolve-uri($location)
                    default
                        return
                        (
                            xdmp:log("DEFAULT SWITCH CASE FOR THIS CODE: " || $head-code || " - " || $url), 
                            $url
                        )
        } catch($e) {
           xdmp:log("u:http-get-url() - Error " || $e//message || " - url: " || $url)
        }
 };

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

(:~
 : Takes a sequence of news-item elements and returns them in another format.
 : Currently possible formats: JSON, HTML, XML.
 : @param $items element(news-item)+ a sequence of 1 or more news items
 : @param $params map:map contaning these key/value pairs: format, from, to, count
 : @return a wrapper item containing the converted news items
 :)
declare function u:convert-news-items(
    $items as element(news-item)+,
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
            let $_ := map:put($nm, "screenshot", u:screenshot-url($item/@id))
            
            return xdmp:to-json($nm)
};

(:~
 : Returns an XML element or a JSON object (depending on the supplied
 : format) for a news provider. As a bonus it will also list the newsitem ids
 : @param $provider element(provider) the XML provider root element
 : @param $format xs:string the desired output format, can be one of json or xml
 : @return an XML or JSON item
 :)
declare function u:convert-provider(
    $provider as element(provider),
    $format as xs:string
) as item()
{
    let $config := json:config("custom")
    let $news-item-urls := (collection("news-item")/news-item[provider[./@id = $provider/@id]]/@id) 
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
    let $type := $event/what/type/string()
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
    $id as xs:string
) as xs:string
{
    $api-base-newsitems || $id || "/screenshot"
};

(:~
 : Given a news-item element, return the URL path that points to the
 : content (this is mainly to have this not all over the place)
 : No extension is given, mime-type is always "text/html"
 :)
declare function u:content-url(
    $news-item as element(news-item)
) as xs:string
{
    $api-base-newsitems || $news-item/@id || "/content"
};

declare function u:item-url(
    $id as xs:string
) as xs:string
{
    $api-base-newsitems || $id
};

declare function u:screenshot-size(
    $id as xs:string
) as xs:integer?
{
    let $path := replace(xdmp:node-uri(collection("id:" || $id)), "item.xml", "screenshot.png")
    return xdmp:binary-size(document($path)/binary())
};

(: Returns a dateTime when the screenshot was successfully saved
 :
 : @param news-item $id as xs:string
 : @returns xs:dateTime or empty sequence
 :)
declare function u:screenshot-date(
    $id as xs:string
) as xs:dateTime?
{
    (collection("event")
        /event[what/newsitem-id[. = $id] 
            and what/type[.='screenshot-saved'] 
            and what/result[.='success']
        ]/when/text()
    ,
        ()
    )[1]
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
    return $api-base-providers || $provider-id
};

declare function u:get-host-from-url(
    $url as xs:string
) as xs:string?
{
    let $t := tokenize($url, '[/\?]')
    return string-join($t[1 to 3], "/")
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
    $api-base-newsitems || $id || "." || $format
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
