xquery version "1.0-ml";

module namespace u="http://mr-utils";

import module namespace cfg = "http://mr-cfg" at "../../config/settings.xqy";
import module namespace json="http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";
import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-doc-2007-01.xqy";

declare namespace jb = "http://marklogic.com/xdmp/json/basic";

(: to generate an identifier hash using hmac-sha1, I need to provide a secret :)
declare variable $secretkey as xs:string := "not-so-secret-key";

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
 : TODO: something more telling than an empty sequence?
 : @return empty-sequence()
 :)
declare function u:record-event(
    $event as element(event)
)
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
 :
 :
 :)
declare function u:create-event(
    $origin as xs:string,
    $message as xs:string,
    $payload as item()*
) as element(event)
{
    let $id := xdmp:hmac-sha1($secretkey, $origin || $message || xdmp:quote($payload) || string(current-dateTime()), "hex")
    return
        <event id="{$id}">
            <when>{current-dateTime()}</when>
            <who>{$origin}</who>
            <message>{$message}</message>
            { (: payload???? :) }
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
    let $link := u:extract-host-from-url($news-item/link)
    let $id := substring(xdmp:md5($link), 1, 9)
    return $id
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
