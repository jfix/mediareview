xquery version "1.0-ml";

import module namespace cfg = "http://mr-cfg" at "/src/config/settings.xqy";
import module namespace json="http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";
import module namespace u = "http://mr-utils" at "/src/lib/xquery/utils.xqm";
declare namespace jb = "http://marklogic.com/xdmp/json/basic";
declare namespace d = "xdmp:encoding-language-detect";
declare namespace xh = "xdmp:http";

(: url of the XML news item to which we need to add a collection :)
declare variable $item as element(news-item) external;

(: everything above 10 is fine, says the documentation, I'm not that fuzzy... :)
declare variable $confidence-threshold as xs:double := 8;

(:
    This module is called via invoke from tasks/language/get.xqy.
    
    It expects one parameter:
    - $url: the URL of the news item document
    
    It will use MarkLogic's built-in language and encoding detection:
    http://docs.marklogic.com/7.0/xdmp:encoding-language-detect
    
    which returns a number of elements like this one:
    <encoding-language xmlns="xdmp:encoding-language-detect">
      <encoding>UTF-8</encoding>
      <language>en</language>
      <score>9.834</score>
    </encoding-language>
    
    Scores of high confidence are >=10.
:)


let $url := xdmp:node-uri($item)
let $content-url := replace($url, "item.xml", "content.html")
let $text := normalize-space(string-join(doc($content-url)//text())) 

(: results are returned in order of decreasing score, i.e. the best first: http://docs.marklogic.com/7.0/xdmp:encoding-language-detect :)
let $result := xdmp:encoding-language-detect(text{$text})[1]

return
    let $lang := $result/d:language/text()
    let $encoding := $result/d:encoding/text()
    let $confidence := $result/d:score/number()
    return
        if ($confidence >= $confidence-threshold)
        then
        (
            xdmp:document-add-collections($url, ("language-detected")),
           
            (: if using $item directly, MarkLogic will complain about not being able to "update external nodes" :)
            xdmp:node-insert-child(document($url)/*, <language encoding="{$encoding}" confidence="{$confidence}">{$lang}</language>),
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
            xdmp:log("DETECTIONNOTRELIABLE: The language detection was not reliable for '" || $url || "', not using this result: " || xdmp:quote($result)),
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
        )
