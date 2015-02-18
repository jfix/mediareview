xquery version "1.0-ml";

(:~
 : Module documentation
 :
 :)

import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-doc-2007-01.xqy";
import module namespace cfg = "http://mr-cfg" at "/src/config/settings.xqy";
import module namespace nd="http://marklogic.com/appservices/utils/normalize-dates" at "/src/lib/xquery/normalize-dates.xqm";
import module namespace u = "http://mr-utils" at "/src/lib/xquery/utils.xqm";

declare namespace xh = "xdmp:http";

declare variable $item as element(item) external;
declare variable $provider-type as xs:string external; 
declare variable $provider-url as xs:string external;
declare variable $current-dateTime as xs:dateTime external;
declare variable $channel-title as xs:string external;

let $guid := replace($item/guid/string(), '\s', '')
let $id := substring(xdmp:md5($guid), 1, 7)
let $uri := string-join(
            ("/news", 
            format-dateTime($current-dateTime, "[Y0001]"),
            format-dateTime($current-dateTime, "[M01]"),
            format-dateTime($current-dateTime, "[D01]"),
            $id, 
            "item.xml"), "/"
        )
(: select correct title, depending on whether source is aggregator like Google RSS or
   single source
:)
let $title as xs:string := 
    functx:trim(
        if ($provider-type eq "_aggregate") 
        then functx:substring-before-last($item/title, " - ") 
        else $item/title
    )
    
let $link as xs:string := 
    functx:trim(
        if ($provider-type eq "_aggregate") 
        then xdmp:url-decode(functx:substring-after-last($item/link, "url=")) 
        else $item/link
    )

let $provider as xs:string := 
    functx:trim(
        if ($provider-type eq "_aggregate") 
        then functx:substring-after-last($item/title, " - ") 
        else $channel-title
    )
    
let $provider-id := u:create-provider-id-from-url($link)
    
let $normalized-dateTime as xs:dateTime := u:normalize-w3c-date($item/pubDate/text())
let $q := 
    if ($provider-type eq '_aggregate')
    then substring-after($provider-url, "q=") 
    else ""

let $doc := <news-item query="{$q}" guid="{$guid}" id="{$id}">
    <title>{ $title }</title>
    <provider id="{$provider-id}">{ $provider }</provider>
    <link>{ $link }</link>
    <date>{ $item/pubDate/text() }</date>
    <normalized-date time="{xs:time($normalized-dateTime)}">{xs:date($normalized-dateTime)}</normalized-date>
    <content>
        <text-only>{
            normalize-space(string-join(
                xdmp:unquote($item/description/text(), (), ("repair-full", "format-xml"))//text()
            , " "))
        }</text-only>
        <full-html>{ xdmp:unquote($item/description/text(), (), ("repair-full", "format-xml")) }</full-html>
    </content>
</news-item>

return 
    if (exists(collection("id:" || $id)))
    then
        xdmp:log("item " || $id || " already exists, not re-inserting")
    else
    (
        xdmp:log("new item " || $id || " found, inserting"),
        xdmp:document-insert(
            $uri,
            $doc,
            $u:default-permissions,
            (
                "id:" || $id, 
                "news-item", 
                "status:imported", 
                (
                    tokenize($q, " ") ! concat("query:",.)
                )
            )
        ),
        u:record-event(
            u:create-event(
                "news-bot", 
                "news item successfully inserted into database", 
                (
                    <type>newsitem-inserted</type>,
                    <result>success</result>,
                    <newsitem-id>{$id}</newsitem-id>,
                    <title>{$title}</title>,
                    <provider-name>{ $provider }</provider-name>,
                    <provider-id>{$provider-id}</provider-id>,
                    <link>{ $link }</link>
                )
            )
        )
    )