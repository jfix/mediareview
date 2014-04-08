setup:
- webdav
- http
- xdbc
- tasks
    /src/tasks/rss-news.xqy
    /src/tasks/get-screenshot.xqy
    
- maintain last-modified properties of documents (keep track of screenshot dates)
- http timeout: 60 -> 600 secs

screenshot-as-a-service:
- git submodule add git://github.com/fzaninotto/screenshot-as-a-service src/lib/screenshot-as-a-service
- cd src/lib/screenshot-as-a-service
- npm install
- nodemon app.js
