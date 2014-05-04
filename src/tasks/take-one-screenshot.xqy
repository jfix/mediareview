xquery version "1.0-ml";

(:~
 : This module is called by @get-screenshots.xqy@ (which is a scheduled task).
 : If the resource identified by $link is an HTML page (and not a PDF or a
 : non-existing page), then a screenshot will be taken by the screenshot-as-a-
 : service.
 :
 :)

import module namespace cfg = "http://mr-cfg" at "/src/config/settings.xqy";
import module namespace u = "http://mr-utils" at "/src/lib/xquery/utils.xqm";
declare namespace xh = "xdmp:http";

(: uri to save the screenshot to :)
declare variable $path as xs:string external;
(: url of the remote page that we want the screenshot of :)
declare variable $link as xs:string external;
(: url of the XML news item to which we need to add a collection :)
declare variable $url as xs:string external;

try {
    let $u := if (starts-with($link, "https://"))
        then
            substring($link, 9)
        else
            substring($link, 8)

    let $head-response := xdmp:http-head($link)
    let $mime-type-acceptable := (contains($head-response//*:content-type/text(), "text/html"))
    let $response-code-ok := (xs:int($head-response//xh:code) < 400)
    let $screenshot := if ($mime-type-acceptable and $response-code-ok)
        then
            xdmp:http-get($cfg:phantomjs-url || xdmp:url-encode($u))
        else
            <xh:response><xh:code>406</xh:code><xh:message>Not taking screenshots of non-HTML resources</xh:message></xh:response>
            
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
                            <path>{$path}</path>
                        )
                    )
                )
            )
} catch($e) {
    xdmp:log("The following error occurred in take-on-screenshot.xqy: " || $e//*:message),
    u:record-event(
        u:create-event(
            "screenshot-bot", 
            "screenshot not saved", 
            (
                <type>screenshot-saved</type>,
                <result>failure</result>,
                <link>{$link}</link>,
                <path>{$path}</path>
            )
        )
    )
}
