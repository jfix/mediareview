xquery version "1.0-ml";

(:
    This module is called by the task scheduler, about once an hour.
    All it does is to invoke the tasks/sentiment/insert.xqy which 
    does the actual work of sentiment detection.
    
    One argument needs to be provided:
    - url: the URL of the news-item
    
    It returns nothing at the moment.
:)

import module namespace utils = "http://mr-utils" at "/src/lib/xquery/utils.xqm";

for $i in (collection("news-item")/news-item[not(sentiment)])[1 to 10]
    let $text := $i//text-only
    
    let $id := data($i/@id)
    let $_ := (
        xdmp:log("DETECTING SENTIMENT FOR THIS ITEM: " || xdmp:node-uri($i)),
        xdmp:log("TEXT SUBMITTED: " || $text)
    )
    
    let $options := 
        <options xmlns="xdmp:http">
                <data>{xdmp:quote(
                    <uclassify xmlns="http://api.uclassify.com/1/RequestSchema" version="1.01">
                    <texts>
                        <textBase64 id="TextId">{xdmp:base64-encode($text)}</textBase64>
                    </texts>
                    <readCalls readApiKey="aN2PpPMJur595SxLaJvGvz4k4">
                        <classify id="classify-{$id}" username="uClassify" classifierName="Sentiment" textId="TextId"/>
                    </readCalls>
                </uclassify>
                )}</data>
        </options>
    
    return
    (
        xdmp:log(
            xdmp:quote(
                xdmp:http-post("http://api.uclassify.com/", $options)
            )
        ),
        xdmp:log("-----------------------------------------------")
    )
