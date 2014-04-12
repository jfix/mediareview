xquery version "1.0-ml";
import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-doc-2007-01.xqy";
import module namespace nd="http://marklogic.com/appservices/utils/normalize-dates" at "/src/lib/xquery/normalize-dates.xqm";

declare namespace xh = "xdmp:http";

(: required for date normalization :)
let $regex:= "^...,\s+[0-3]?\d\s+\S+\s+\d\d\d\d\s+[0-2]?\d:[0-5]\d:[0-5]\d\s+...$"

let $q := "oecd"
let $u := "https://news.google.com/news/feeds?pz=1&amp;cf=all&amp;ned=us&amp;hl=en&amp;output=rss&amp;q=" || $q || "&amp;num=100"
let $dt := current-dateTime()

let $r := xdmp:http-get($u)
let $d := $r[2]
let $h := $r[1]
let $_ := xdmp:log("rss-news.xqy: " || $h//xh:code/text() || " " || $h//xh:message/text() || " -- " || count($d//item) || " items retrieved.")

return 
    
    for $item in $d//item
        let $guid := $item/guid/string()
        let $id := substring(xdmp:md5($guid), 1, 7)
        let $uri := string-join(
            ("/news", 
            format-dateTime($dt, "[Y0001]"),
            format-dateTime($dt, "[M01]"),
            format-dateTime($dt, "[D01]"),
            $id, 
            "item.xml"), "/"
        )
        let $normalized-dateTime := nd:normalize-datetime($item/pubDate/text(), $regex)
        
        let $doc := <news-item query="{$q}" guid="{$guid}" id="{$id}">
            <title>{ functx:substring-before-last($item/title, " - ") }</title>
            <provider>{ functx:substring-after-last($item/title, " - ") }</provider>
            <link>{ xdmp:url-decode(functx:substring-after-last($item/link, "url=")) }</link>
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
                    xdmp:default-permissions(),
                    (
                        "id:" || $id, 
                        "news-item", 
                        "status:imported", 
                        (
                            tokenize($q, " ") ! concat("query:",.)
                        )
                    )
                )
            )