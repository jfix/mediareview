setup:
- webdav
- http (authentication: app-level, default-user: mr-end-user)
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

users
-----
two users:
1) mr-backoffice-user
--- mr-add-documents-role
    xdmp:invoke execute privilege
    any-collection execute privilege
    xdbc:eval execute privilege (for use with oxygenxml only)
    xdmp:http-post execute privilege
    xdmp:filesystem-file (rss-news.xqy)
    filesystem-access role (to read files in apps/assets)
    
--- mr-delete-documents-role
    xdmp:invoke execute privilege
--- mr-read-documents-role
    xdmp:get-server-field (for rxq:rewrite)
    xdmp:set-server-field (for rxq:rewrite)

2) mr-end-user
--- mr-read-documents-role

roles
-----
- mr-add-documents-role
-- insert
-- update
-- read
- mr-delete-documents-role
-- delete
-- read

- mr-read-documents-role
-- read


--
associate http server with mr-end-user
--


screenshot-as-a-service:
- git submodule add git://github.com/fzaninotto/screenshot-as-a-service src/lib/screenshot-as-a-service
- cd src/lib/screenshot-as-a-service
- npm install
- nodemon app.js

rxq
- git submodule add git://github.com/xquery/rxq src/lib/rxq
- update of rewriter/error files
- copy rxq-rewriter.xqy and rxq.xqy to /src/lib/xquery
