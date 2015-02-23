xquery version "1.0-ml";

(:~
 : This module is called by @gtasks/screenshot/get.xqy@ (which is a scheduled task).
 : If the resource identified by $link is an HTML page (and not a PDF or a
 : non-existing page), then a screenshot will be taken by the screenshot-as-a-
 : service.
 :
 :)

import module namespace cfg = "http://mr-cfg" at "/src/config/settings.xqy";
import module namespace u = "http://mr-utils" at "/src/lib/xquery/utils.xqm";
declare namespace xh = "xdmp:http";

declare variable $item as element(news-item) external;
(: DEBUG: :)
(:declare variable $item as element(news-item) := collection("id:012f078")/news-item;:)

(: define theses variable outside the try because we may need them even in 
   the catch section. :)

(: url of the XML news item to which we need to add a collection :)
declare variable $url as xs:string := xdmp:node-uri($item);
(: uri to save the screenshot to :)
declare variable $path as xs:string := replace($url, "item.xml", "screenshot.png");
(: url of the remote page that we want the screenshot of :)
declare variable $link as xs:string? := u:http-get-url($item//link);
(: the newsitem-id :)
declare variable $id as xs:string := $item/@id;

try {
    let $head-response := xdmp:http-head($link, $u:http-get-options)
    
    let $mime-type-acceptable := (
        contains($head-response//xh:content-type/text(), "html") (: either HEAD response contains 'html' something :)
            or 
        string-length($head-response//xh:content-type/text()) = 0 (: or at least it's empty ... benefit of the doubt :)
    )
    let $response-code as xs:int := $head-response//xh:code
    let $screenshot := if ($mime-type-acceptable)
        then
            xdmp:http-get($cfg:phantomjs-url || xdmp:url-encode($link), $u:http-get-options)
        else
            <xh:response>
                <xh:code>406</xh:code>
                <xh:message>Not taking screenshots of non-HTML resources: {$head-response//xh:content-type/text()}.</xh:message>
            </xh:response>
    
    let $response-code := data($screenshot[1]//xh:code)
    return 
        if ($response-code ne 200)
        then
            error(QName("", "URLERROR"), $response-code || ": " || $screenshot[1]//xh:message || " - " || $link)
        else
            (
                xdmp:document-insert(
                    $path, 
                    binary{xs:hexBinary($screenshot[2])}, 
                    $u:default-permissions, 
                    ("screenshot")
                ),
                xdmp:document-add-collections($url, ("screenshot-saved")),
                u:record-event(
                    u:create-event(
                        "screenshot-bot", 
                        "screenshot successfully saved", 
                        (
                            <type>screenshot-saved</type>,
                            <result>success</result>,
                            <link>{$link}</link>,
                            <newsitem-id>{$id}</newsitem-id>,
                            <path>{$path}</path>
                        )
                    )
                )
            )
} catch($e) {
    xdmp:log("The following error occurred in take-one-screenshot.xqy: " || $e//*:message),
    xdmp:log("Additional information from tasks/content/insert.xqy: link: " || string($link) || " - id: " || $id),
    xdmp:document-add-collections($url, ("screenshot-failed")),
    
    (: 
        given that we also set the collection "screenshot-failed" 
        there will be just one failure event recorded.
    :)
    u:record-event(
        u:create-event(
            "screenshot-bot", 
            "screenshot not saved", 
            (
                <type>screenshot-saved</type>,
                <result>failure</result>,
                <link>{$link}</link>,
                <newsitem-id>{$id}</newsitem-id>,
                <path>{$path}</path>
            )
        )
    )
}
