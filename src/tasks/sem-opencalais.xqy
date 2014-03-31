xquery version "1.0-ml";
import module namespace functx = "http://www.functx.com" at "/MarkLogic/functx/functx-1.0-doc-2007-01.xqy";
import module namespace cfg = "http://mr-cfg" at "/src/config/settings.xqy";

let $apibase := "http://api.opencalais.com/enlighten/rest/"
let $key := $cfg:opencalais-apikey
let $content := "OECD Digital Economy Review May Hit Ireland Hardest Tax-news.com Proposals in the Organisation for Economic Co-operation and Development's ( OECD's ) discussion draft on the digital taxation, to change the way high-tech multinational companies are taxed, will only benefit large countries with large markets, Chartered ... Nearly 10 percent of Ireland's young population emigrated during economic crisis IrishCentral all 2 news articles »"
let $content-type := "text/raw"
let $outputformat := "text/n3"

let $options := <options xmlns="xdmp:http">
        <headers>
            <x-calais-licenseID>{ $key }</x-calais-licenseID>
            <content-type>{ $content-type }</content-type>
            <accept>{ $outputformat }</accept>
        </headers>
        <data>{ $content }</data>
    </options>
    
let $response := xdmp:http-post(
    $apibase,
    $options
)

return $response
