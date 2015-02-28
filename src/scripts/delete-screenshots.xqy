xquery version "1.0-ml";

(: 
   watch out, this script will delete 
   ALL SCREENSHOTS from the database.
   
   you have been warned!
:)

for $i in collection("screenshot-saved")
    let $uri := xdmp:node-uri($i)
    
    return (
        try { (
            (: remove collection 'screenshot-saved' from item.xml file :)
            xdmp:document-remove-collections($uri, "screenshot-saved")
        ) } catch($e) { () }
        ,
        try { (
            (: delete contents.html document :)
            xdmp:document-delete(replace($uri, "item.xml", "screenshot.png"))
        ) } catch($e) { () }
    )
