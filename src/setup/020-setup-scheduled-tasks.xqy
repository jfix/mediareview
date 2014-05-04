xquery version "1.0-ml";

import module namespace admin = "http://marklogic.com/xdmp/admin"  at "/MarkLogic/admin.xqy";

let $config := admin:get-configuration()

let $task-root := "/Users/jakob/Projects/mediareview/"
let $task-database := xdmp:database()
let $task-modules := 0 (: file system:)
let $task-user := xdmp:user("mr-backoffice-user")
let $task-priority := "normal"
let $task-group := admin:group-get-id($config, "Default")

let $get-news-task := admin:group-hourly-scheduled-task(
   "/src/tasks/rss-news.xqy",
   $task-root,
   1,
   20,
   $task-database,
   $task-modules,
   $task-user,
   xdmp:host(),
   $task-priority
)

let $extract-providers-task := admin:group-hourly-scheduled-task(
   "/src/tasks/extract-providers.xqy",
   $task-root,
   1,
   25,
   $task-database,
   $task-modules,
   $task-user,
   xdmp:host(),
   $task-priority
)

let $get-screenshots-task := admin:group-hourly-scheduled-task(
   "/src/tasks/get-screenshots.xqy",
   $task-root,
   1,
   30,
   $task-database,
   $task-modules,
   $task-user,
   xdmp:host(),
   $task-priority
)

let $detect-languages-task := admin:group-hourly-scheduled-task(
   "/src/tasks/detect-languages.xqy",
   $task-root,
   1,
   40,
   $task-database,
   $task-modules,
   $task-user,
   xdmp:host(),
   $task-priority
)

let $config := admin:group-add-scheduled-task($config, $task-group, $detect-languages-task)
let $config := admin:group-add-scheduled-task($config, $task-group, $extract-providers-task)
let $config := admin:group-add-scheduled-task($config, $task-group, $get-news-task)
let $config := admin:group-add-scheduled-task($config, $task-group, $get-screenshots-task)

return admin:save-configuration-without-restart($config)
