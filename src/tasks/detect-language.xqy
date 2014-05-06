xquery version "1.0-ml";

(:
    This module is called via invoke from detect-languages.xqy (note 
    the plural form).
    
    It expects one parameter:
    - $url: the URL of the news item document
    
    It will call the detectlanguage.com API and extract the language from 
    the returned results. If a language could be detected, it will do
    two things:
    - insert a <language confidence="[score]">[id]</language> as last child
      of the <news-item> element
    - add the collection "language-detected" to the document
    
    If it cannot connect to the API, or if the results are no reliable
    errors are returned.
    
    The result returned by the API may look like this (usually, the 
    detections array contains just one object):

    {
        "data":{
            "detections":[
                {
                    "language":"ko",
                    "isReliable":true,
                    "confidence":36.74
                },
                {
                    "language":"en",
                    "isReliable":false,
                    "confidence":0.01
                },
                {
                    "language":"hu",
                    "isReliable":false,
                    "confidence":0.01
                }
            ]
        }
    }
:)

import module namespace cfg = "http://mr-cfg" at "/src/config/settings.xqy";
import module namespace json="http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";
import module namespace u = "http://mr-utils" at "/src/lib/xquery/utils.xqm";
declare namespace jb = "http://marklogic.com/xdmp/json/basic";
declare namespace xh = "xdmp:http";

(: url of the XML news item to which we need to add a collection :)
declare variable $url as xs:string external;

try {
    let $doc := document($url)
    
    (: It turned out to work better, for larger texts, to POST the request,
       although a GET works too, in theory. :)
    let $res := xdmp:http-post($cfg:detectlanguage-query-url, 
        <options xmlns="xdmp:http">
            <headers><content-type>application/x-www-form-urlencoded</content-type></headers>
        </options>, 
        text{ "key=" || $cfg:detectlanguage-apikey || "&amp;q=" || $doc//text-only }
    )
    let $response-code := data($res[1]//xh:code)

    return
        if ($response-code ne 200)
        then
            fn:error(QName("", "URLERROR"), $response-code || ": " || $res[1]//xh:message || " - " || $url)
        else
            let $item := json:transform-from-json($res[2])//jb:json[jb:isReliable ='true'][1]
            return
                if ($item)
                then
                    let $lang := $item/jb:language/text()
                    let $confidence := $item/jb:confidence/text()
                    return
                       (
                       xdmp:document-add-collections($url, ("language-detected")),
                       xdmp:node-insert-child($doc/news-item, <language confidence="{$confidence}">{$lang}</language>),
                       u:record-event(
                             u:create-event(
                                 "language-bot", 
                                 "language successfully detected", 
                                 (
                                     <type>language-detected</type>,
                                     <result>success</result>,
                                     <language>{$lang}</language>,
                                     <confidence>{$confidence}</confidence>,
                                     <text>{$doc//text-only}</text>,
                                     <link>{$item//link/text()}</link>,
                                     <id>{$doc/@id}</id>,
                                     <path>{$url}</path>
                                 )
                             )
                         )

                       )
                else
                (
                    xdmp:log("DETECTIONNOTRELIABLE: The language detection was not reliable for '" || $url || "', not using this result: " || xdmp:quote($res[2])),
                    u:record-event(
                        u:create-event(
                            "language-bot", 
                            "language not detected", 
                            (
                                <type>language-detected</type>,
                                <result>failure</result>,
                                <text>{$doc//text-only}</text>,
                                <link>{$item//link/text()}</link>,
                                <id>{$doc/@id}</id>,
                                <path>{$url}</path>
                            )
                        )
                    )

                    (:fn:error(QName("", "DETECTIONNOTRELIABLE"), "The language detection was not reliable for '" || $url || "', not using result."):)
                )
} catch($e) {
    xdmp:log("DETECTLANGUAGEERROR: "|| $e//*:message)
(:    fn:error(QName("", "DETECTLANGUAGEERROR"), $e//*:message):)
}
