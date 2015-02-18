xquery version "1.0-ml";

(:~
 : This module is called regularly (depending on how the scheduled task
 : was configured) and reads the sources.xml file which contains a list
 : of URLs that return RSS (or other formats once/if supported). It will
 : then invoke another module for each extract news item in each result
 : document.
 :)
 
declare namespace xh = "xdmp:http";

(: where to find the definitions of the sources of information :)
let $sources := xdmp:unquote(xdmp:filesystem-file( xdmp:modules-root() || "src/config/sources.xml"))/sources/source
let $dt := current-dateTime()

for $s in $sources
    let $u as xs:string := $s/url
    let $p as xs:string := $s/provider

    let $r := xdmp:http-get(
        $u,
        <options xmlns="xdmp:http-get">
           <format xmlns="xdmp:document-get">xml</format>
        </options>
    )
    let $d := $r[2]
    let $h := $r[1]
    
    let $_ := xdmp:log("rss-news.xqy: URL: " || $u || " - PROVIDER: " || $p || ": " || $h//xh:code/text() || " " || $h//xh:message/text() || " -- " || count($d//item) || " items retrieved.")
    
return 
    
    for $item in $d//item
        (: remove spaces from identifier string :)
        let $guid := replace($item/guid/string(), '\s', '')
        let $id := substring(xdmp:md5($guid), 1, 7)
        
        return
            if (not(exists(collection("id:" || $id))))
            then
                xdmp:invoke(
                    "/src/tasks/newsitem/insert.xqy", 
                    (
                        map:entry("item", $item),
                        map:entry("channel-title", $d//channel/title/text()),
                        map:entry("provider-url", $u),
                        map:entry("provider-type", $p),
                        map:entry("current-dateTime", $dt)
                    )
                )
            else
                ()