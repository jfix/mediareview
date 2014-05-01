setup:
- webdav
- http
- xdbc
- tasks
    /src/tasks/rss-news.xqy
    /src/tasks/get-screenshot.xqy
    /src/tasks/detect-languages.xqy
    /src/tasks/extract-providers.xqy

- enable collection lexicons
    
---------------
 xquery version "1.0-ml";
  import module namespace admin = "http://marklogic.com/xdmp/admin" 
      at "/MarkLogic/admin.xqy";

  let $config := admin:get-configuration()
 
  let $task := admin:group-hourly-scheduled-task(
      "/src/tasks/extract-providers.xqy",
      "/doc",
      2,
      30,
      xdmp:database("Documents"),
      0,
      xdmp:user("Jim"), 
      0)

  let $addTask := admin:group-add-scheduled-task($config, 
      admin:group-get-id($config, "Default"), $task)

  return 
      admin:save-configuration($addTask)
 
  (: Creates an hourly scheduled task and adds it to the "Default" group. :)
---------------
    
- maintain last-modified properties of documents (keep track of screenshot dates)
- http timeout: 60 -> 600 secs
- element-range-index of type date for normalized-date element
- element-range-index of type string for language element
- element-range-index of type string for provider element

screenshot-as-a-service:
- git submodule add git://github.com/fzaninotto/screenshot-as-a-service src/lib/screenshot-as-a-service
- cd src/lib/screenshot-as-a-service
- npm install
- nodemon app.js

rxq
- git submodule add git://github.com/xquery/rxq src/lib/rxq
- update of rewriter/error files
- copy rxq-rewriter.xqy and rxq.xqy to /src/lib/xquery
