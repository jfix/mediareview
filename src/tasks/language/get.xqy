xquery version "1.0-ml";

(:
    This module is called by the task scheduler, about once an hour.
    All it does is to invoke the detect-language.xqy (note singular
    form) which does the actual work of language detection.
    
    It will check before invoking the other module whether the 
    contingent of queries has been exhausted or not (as we're using
    the free plan, we're limited to 5000 queries or 1MB of data bytes 
    per day).  
    
    One argument needs to be provided:
    - url: the URL of the news-item
    
    It returns nothing at the moment.
:)

import module namespace utils = "http://mr-utils" at "/src/lib/xquery/utils.xqm";

(: instead of using just the tiny bit of text in an RSS item, let's use the contents we have retrieved (if any) :)
for $i in (collection("content-retrieved")/news-item[not(language)])[1 to 100]
    let $_ := xdmp:log("DETECT LANGUAGE FOR THIS ITEM: " || xdmp:node-uri($i))
    
    return
        xdmp:invoke("/src/tasks/language/insert.xqy", (map:new(map:entry("item", $i))))
