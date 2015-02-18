xquery version "1.0-ml";
import module namespace admin = "http://marklogic.com/xdmp/admin"  at "/MarkLogic/admin.xqy";
declare namespace gr = "http://marklogic.com/xdmp/group";

let $config := admin:get-configuration()
let $task-group := admin:group-get-id($config, "Default")
(: only delete tasks that belong to media-review, hence the xpath predicate :)
let $tasks := admin:group-get-scheduled-tasks($config, $task-group)[gr:task-path[starts-with(., "/src/tasks")]/text()]
let $config := admin:group-delete-scheduled-task($config, $task-group, $tasks)

return (
    admin:save-configuration-without-restart($config)
    ,
    $tasks
    )
