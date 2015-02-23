xquery version "1.0-ml";

(:~
 : This module is spawned from the @tasks/content/get.xqy@ module
 : which itself is launched periodically by the Task Scheduler.
 : Its purpose is to retrieve the HTML contents as such, to tidy
 : it up and to store it in the database for future use (like a
 : more intelligent copy than a screenshot).
 :)

import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-doc-2007-01.xqy";
import module namespace cfg = "http://mr-cfg" at "/src/config/settings.xqy";
import module namespace nd="http://marklogic.com/appservices/utils/normalize-dates" at "/src/lib/xquery/normalize-dates.xqm";
import module namespace u = "http://mr-utils" at "/src/lib/xquery/utils.xqm";
import module namespace mem="http://xqdev.com/in-mem-update" at "/MarkLogic/appservices/utils/in-mem-update.xqy";

declare namespace h = "http://www.w3.org/1999/xhtml";
declare namespace xh = "xdmp:http";

(: DEBUG :)
(:declare variable $item as element(news-item) := collection("id:d3a8fb8")/news-item;:)
declare variable $item as element(news-item) external;

let $doc-path := xdmp:node-uri($item)
let $doc-id := data($item/@id)
let $content-path := replace($doc-path, "item.xml", "content.html")
(: if URL referenced by link element doesn't exist then what?! :)
let $content-link := $item//link

return
    if (not($content-link))
    then
        xdmp:log("PROBLEM WITH NON-EXISTING CONTENT LINK: " || $content-link)
    else
        let $readability-link := string-join(($cfg:readability-parser-url, "url=" || $content-link), "&amp;")
        let $content-response := xdmp:http-get($readability-link)
        
        return 
            (: insert result if 200 :) 
            if ($content-response[1]//xh:code = 200)
            then
                try {
                    let $content-doc := xdmp:unquote($content-response[2]/response/content/text(), "", ("repair-full"))
                    let $_ := xdmp:log("CONTENT INSERT: actual content doc: " || xdmp:quote($content-doc))
                    return (
                        xdmp:log("CONTENT INSERT: new content for " || $doc-id || " found, inserting"),
                        xdmp:document-add-collections($doc-path, ("content-retrieved")),
                        u:record-event(
                            u:create-event(
                                "content-bot", 
                                "content item successfully stored in database", 
                                (
                                    <type>content-retrieved</type>,
                                    <result>success</result>,
                                    <content-url>{$content-link}</content-url>,
                                    <content-path>{$content-path}</content-path>,
                                    <content-type>{$content-response[1]//xh:content-type}</content-type>,
                                    <content-length>{$content-response[1]//xh:content-length}</content-length>,
                                    <newsitem-id>{$doc-id}</newsitem-id>
                                )
                            )
                        ),
                        xdmp:document-insert(
                            $content-path,
                            $content-doc,
                            $u:default-permissions,
                            (
                                "content-item", 
                                "status:stored",
                                "mime-type:" || ($content-response[1]//xh:content-type, "text/html")[1],
                                "content-length:"|| $content-response[1]//xh:content-length
                            )
                        )
                    )
                } catch($e) {
                    ()
                }
            (: otherwise ... don't insert ... but generate a 'failure' event :)
            else
            (        
                xdmp:log("retrieval of " || $content-link || " returned a " || $content-response[1]//xh:code),
                u:record-event(
                    u:create-event(
                        "content-bot",
                        "content item could not be retrieved", 
                        (
                            <type>content-retrieved</type>,
                            <result>failure</result>,
                            <content-url>{$content-link}</content-url>,
                            <http-code>{$content-response[1]//xh:code}</http-code>,
                            <http-message>{$content-response[1]//xh:message}</http-message>,
                            <newsitem-id>{$doc-id}</newsitem-id>
                        )
                    )
                )
            )
