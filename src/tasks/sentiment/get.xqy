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

for $i in cts:search(/news-item, 
    cts:and-not-query(
        cts:collection-query("content-retrieved")
        ,
        cts:collection-query("sentiment-determined")
    )
)[1 to 1000]
return
    xdmp:invoke("/src/tasks/sentiment/insert.xqy", (map:new(map:entry("item", $i))))
