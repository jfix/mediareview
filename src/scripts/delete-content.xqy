xquery version "1.0-ml";

(: 
   watch out, this script will delete 
   ALL CONTENT ITEMS from the database
   
   you have been warned!
:)

for $i in collection("content-retrieved")
    let $uri := xdmp:node-uri($i)
    
    return (
        try { (
            (: remove collection 'content-retrieved' from item.xml file :)
            xdmp:document-remove-collections($uri, "content-retrieved")
        ) } catch($e) { () }
        ,
        try { (
            (: delete contents.html document :)
            xdmp:document-delete(replace($uri, "item.xml", "contents.html"))
        ) } catch($e) { () }
    )
