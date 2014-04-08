xquery version "1.0-ml";
import module namespace cfg = "http://mr-cfg" at "/src/config/settings.xqy";
declare namespace xh = "xdmp:http";

(: uri to save the screenshot to :)
declare variable $path as xs:string external;
(: url of the remote page that we want the screenshot of :)
declare variable $link as xs:string external;
(: url of the XML news item to which we need to add a collection :)
declare variable $url as xs:string external;

let $u := if (starts-with($link, "https://"))
    then
        substring($link, 9)
    else
        substring($link, 8)
        
let $screenshot := xdmp:http-get($cfg:phantomjs-url || xdmp:url-encode($u))
let $response-code := data($screenshot[1]//xh:code)
return 
    if ($response-code ne 200)
    then
        error(QName("", "URLERROR"), $response-code || ": " || $screenshot[1]//xh:message || " - " || $link)
    else
        (
        xdmp:document-insert($path, binary{xs:hexBinary($screenshot[2])}, (), ("screenshot")),
        xdmp:document-add-collections($url, ("screenshot-saved"))
        )
