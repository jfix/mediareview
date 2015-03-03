xquery version "1.0-ml";
import module namespace cfg = "http://mr-cfg" at "/src/config/settings.xqy";
import module namespace u = "http://mr-utils" at "/src/lib/xquery/utils.xqm";
declare namespace xh = "xdmp:http";

(:~
 : Called as a scheduled task, tries to figure out
 : whether contents is HTML (may not always be the
 : case!), and if so invokes a module to handle
 : the retrieval of the HTML and its storage.
 :)

for $i in (cts:search(/news-item, 
    cts:and-not-query(
        cts:collection-query("news-item")
        ,
        cts:or-query((
            cts:collection-query("content-retrieved"),
            cts:collection-query("content:retrieval-failure")
        ))
    )
))[1 to 100] (: restrictive predicate could be removed at some stage :)
    
    let $url := u:http-get-url($i//link)
    return
        if ($url)
        then
            xdmp:invoke("/src/tasks/content/insert.xqy", 
                (
                    map:entry("item", $i)  
                )
            )
        else
            xdmp:log("tasks/content/get.xqy: u:http-get-url returned empty for url: " || $i//link)
        
 