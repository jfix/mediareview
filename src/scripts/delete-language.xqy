xquery version "1.0-ml";

(: 
   watch out, this script will delete 
   ALL DETECTED LANGUAGE elements from the database.
   
   you have been warned!
:)

for $i in collection("language-detected")
    let $uri := xdmp:node-uri($i)
    
    return (
        try { (
            (: remove collection 'screenshot-saved' from item.xml file :)
            xdmp:document-remove-collections($uri, "language-detected")
        ) } catch($e) { () }
        ,
        try { (
            (: delete contents.html document :)
            xdmp:node-delete($i/news-item/language)
        ) } catch($e) { () }
    )
