xquery version "1.0-ml";

(: 
   watch out, this script will delete 
   ALL SENTIMENTS from the database.
   
   You will be completely numb afterwards :-(
   
   you have been warned!
:)

for $i in collection("sentiment-determined")
    let $uri := xdmp:node-uri($i)
    
    return (
        try { (
            (: remove collection 'screenshot-saved' from item.xml file :)
            let $collections := xdmp:document-get-collections($uri)
            return
                for $c in xdmp:document-get-collections($uri)
                return
                    if (contains($c, "sentiment-")) 
                    then xdmp:document-remove-collections($uri, $c) 
                    else ()
        ) } catch($e) { () }
        ,
        try { (
            (: delete <sentiment> element in each document :)
            xdmp:node-delete($i/*//sentiment)
        ) } catch($e) { () }
    )
