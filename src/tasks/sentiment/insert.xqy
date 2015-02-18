xquery version "1.0-ml";

(:
    This module is called via invoke from @tasks/sentiment/get.xqy@.
    
    It expects one parameter:
    - $url: the URL of the news item document
    
    It will call the api.uclassify.com API and attempt to determine the 
    sentiment (positive or negative) based on either the RSS snippet, or, 
    preferably, if it exists, the contents as extracted by the readibility 
    API.
    
    If a sentiment could be detected, it will do
    two things:
    - insert a <sentiment confidence="[score]">[id]</sentiment> as last child
      of the <news-item> element
    - add the collections "sentiment-detected" and 
      "sentiment:positive" or "sentiment:negative: or "sentiment:undecided"
      to the document.
    
    If it cannot connect to the API, or if the results are no reliable
    errors are returned.
    
    The result returned by the API may look like this:

    <uclassify xmlns="http://api.uclassify.com/1/ResponseSchema" version="1.01">
        <status success="true" statusCode="2000" />
        <readCalls>
            <classify id="cls1">
                <classification textCoverage="1">
                    <class className="negative" p="0.501319" />
                    <class className="positive" p="0.498681" />
                </classification>
            </classify>
        </readCalls>
    </uclassify>
    
    More info on the API: http://www.uclassify.com/XmlApiDocumentation.aspx
:)

(:
        
        TODO TODO TODO

:)

import module namespace cfg = "http://mr-cfg" at "/src/config/settings.xqy";
import module namespace json="http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";
import module namespace u = "http://mr-utils" at "/src/lib/xquery/utils.xqm";
declare namespace jb = "http://marklogic.com/xdmp/json/basic";
declare namespace xh = "xdmp:http";

(: url of the XML news item to which we need to add a collection :)
declare variable $id as xs:string external;
declare variable $item as element(news-item) := collection("id:" || $id)/news-item;

try {
    let $url := xdmp:node-uri($item)
    
    (: It turned out to work better, for larger texts, to POST the request,
       although a GET works too, in theory. :)
    let $res := xdmp:http-post($cfg:detectlanguage-query-url, 
        <options xmlns="xdmp:http">
            <headers><content-type>application/x-www-form-urlencoded</content-type></headers>
        </options>, 
        text{ "key=" || $cfg:detectlanguage-apikey || "&amp;q=" || $item//text-only }
    )
    let $response-code := data($res[1]//xh:code)

    return
        if ($response-code ne 200)
        then
            fn:error(QName("", "URLERROR"), $response-code || ": " || $res[1]//xh:message || " - " || $url)
        else
            let $result-item := json:transform-from-json($res[2])//jb:json[jb:isReliable ='true'][1]
            return
                if ($result-item)
                then
                    let $lang := $result-item/jb:language/text()
                    let $confidence := $result-item/jb:confidence/text()
                    return
                       (
                       xdmp:document-add-collections($url, ("language-detected")),
                       
                       (: if using $item directly, MarkLogic will complain about not being able to "update external nodes" :)
                       xdmp:node-insert-child(document(xdmp:node-uri($item))/*, <language confidence="{$confidence}">{$lang}</language>),
                       u:record-event(
                             u:create-event(
                                 "language-bot", 
                                 "language successfully detected", 
                                 (
                                     <type>language-detected</type>,
                                     <result>success</result>,
                                     <language>{$lang}</language>,
                                     <confidence>{$confidence}</confidence>,
                                     <text>{$item//text-only}</text>,
                                     <link>{$item//link/text()}</link>,
                                     <newsitem-id>{data($item/@id)}</newsitem-id>,
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
                                <text>{$item//text-only}</text>,
                                <link>{$item//link/text()}</link>,
                                <newsitem-id>{data($item/@id)}</newsitem-id>,
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
