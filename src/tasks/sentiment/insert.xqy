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
    
    @textCoverage gives an indication as of how much of the text was
    found in the training corpus (0 = none, 1 = all words were found);
    can be used to evaluate confidence of the result
    More info on the API: http://www.uclassify.com/XmlApiDocumentation.aspx
:)

import module namespace cfg = "http://mr-cfg" at "/src/config/settings.xqy";
import module namespace u = "http://mr-utils" at "/src/lib/xquery/utils.xqm";
declare namespace xh = "xdmp:http";
declare namespace class = "http://api.uclassify.com/1/ResponseSchema";

(:declare variable $item as element(news-item) external;:)
declare variable $item as element(news-item) := collection("id:f9bbd62")/*;

let $text := "excellent average" (:string-join(doc(u:content-path($item/@id))//text(), " "):)

let $options := 
    <options xmlns="xdmp:http">
        <data>{xdmp:quote(
            <uclassify xmlns="http://api.uclassify.com/1/RequestSchema" version="1.01">
            <texts>
                <textBase64 id="TextId">{xdmp:base64-encode($text)}</textBase64>
            </texts>
            <readCalls readApiKey="{$cfg:uclassify-read-apikey}">
                <classify id="classify{$item/@id}" username="uClassify" classifierName="Sentiment" textId="TextId"/>
            </readCalls>
        </uclassify>
        )}</data>
    </options>
 
let $result := xdmp:http-post("http://api.uclassify.com/", $options)
return
    if ($result[1]/xh:code[. = 200])
    then
        let $class-result := xdmp:unquote($result[2])
        return 
            if ($class-result/class:uclassify/class:status/@statusCode[.=2000])
            then
                let $classification := $class-result//class:classification
                let $text-coverage := number($classification/@textCoverage)
                let $sentiment := (for $i in $classification/class:class order by $i/@p return $i)[1]
                return ($text-coverage, $sentiment)
            else
                ()
    else
        ()
        

