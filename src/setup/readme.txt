setup:
- webdav
- http
- xdbc
- tasks
    /src/tasks/rss-news.xqy
    /src/tasks/get-screenshot.xqy
    /src/tasks/detect-languages.xqy
    
- maintain last-modified properties of documents (keep track of screenshot dates)
- http timeout: 60 -> 600 secs
- element-range-index of type date for normalized-date element
- element-range-index of type string for language element

screenshot-as-a-service:
- git submodule add git://github.com/fzaninotto/screenshot-as-a-service src/lib/screenshot-as-a-service
- cd src/lib/screenshot-as-a-service
- npm install
- nodemon app.js

rxq
- git submodule add git://github.com/xquery/rxq src/lib/rxq
- update of rewriter/error files
- copy rxq-rewriter.xqy and rxq.xqy to /src/lib/xquery
