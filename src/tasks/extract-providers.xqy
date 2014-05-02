xquery version "1.0-ml";
import module namespace u = "http://mr-utils" at "/src/lib/xquery/utils.xqm";

(:~
 : This is the module that gets called at regular intervals by the task
 : scheduler to record provider information. A specific module is invoked
 : for those providers that don't exist yet.
 :
 :)

for $item in collection("news-item")
    let $id := u:create-provider-id($item/news-item)    
    return
        if (not(exists(collection("id:" || $id))))
        then
            xdmp:invoke("/src/tasks/record-one-provider.xqy", map:entry("item", $item))
        else
            ()
            (: xdmp:log($id || " is already there, ignoring.") :)

