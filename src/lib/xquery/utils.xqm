xquery version "1.0-ml";

module namespace u="http://mr-utils";

import module namespace cfg = "http://mr-cfg" at "/src/config/settings.xqy";
import module namespace json="http://marklogic.com/xdmp/json" at "/MarkLogic/json/json.xqy";
declare namespace jb = "http://marklogic.com/xdmp/json/basic";

(:~
 : test whether we can still send requests to the detectlanguage.com api
 : or whether we've exhausted the current contingent 
 : (of either the number of daily requests or the limit of bytes that can be sent).
 : returns true or false
 :)
declare function u:detectlanguage-api-requests-remaining(
) as xs:boolean
{
    try {
        let $s := json:transform-from-json(xdmp:http-get($cfg:detectlanguage-status-url)[2])
        return 
            xs:integer($s//jb:daily__requests__limit) > xs:integer($s//jb:requests)
            and
            xs:integer($s//jb:daily__bytes__limit) > xs:integer($s//jb:bytes)
    } catch ($e) {
        (xdmp:sleep(1000), 
         xdmp:log("oops, socket time, wait some and try again!"), 
         u:detectlanguage-api-requests-remaining())
    }
};
