xquery version "1.0-ml";
import module namespace cfg = "http://mr-cfg" at "/src/config/settings.xqy";
declare namespace xh = "xdmp:http";

for $i in cts:search(/news-item, cts:and-not-query(
    cts:collection-query("news-item")
    ,
    cts:collection-query("screenshot-saved")
    )
)[1 to 10] (: only retrieving a max of ten screenshots each time :)
   
let $doc-url := xdmp:node-uri($i)

(: make double-sure not to re-take snapshots :)
let $has-screenshot := ("screenshot-saved" = xdmp:document-get-collections(xdmp:node-uri($i)))

return 
    if (not($has-screenshot))
    then
        let $path := replace(xdmp:node-uri($i), "item.xml", "screenshot.png")
        
        (: TODO: test news-item URL is available ... :)
        
        let $screenshot := xdmp:http-get($cfg:phantomjs-url || xdmp:url-encode($i//link))
        let $response-code := data($screenshot[1]//xh:code)
        return 
            if ($response-code ne 200)
            then
                error(QName("", "URLERROR"), $response-code || ": " || $screenshot[1]//xh:message || " - " || $i//link)
            else
                (
                xdmp:document-insert($path, binary{xs:hexBinary($screenshot[2])}, (), ("screenshot")),
                xdmp:document-add-collections($doc-url, ("screenshot-saved"))
                )
    else ()
