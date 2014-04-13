    $( document ).ready(function() { 
        var options = {
            title: {
            }, 
            chart: {
                renderTo: 'container',
                type: 'column'
            },
            legend: {
                enabled: false  
            },
            credits: {
                enabled: false
            },
            tooltip: {
                borderWidth: 0,
                borderRadius: 1
            },
            xAxis: {
                type: "datetime",
                labels: {
                    format: '{value:%e %b \'%y}' // %a, %e %b \'%y ==> Wed, 1 Apr '14
                },
                title: {}
            },
            yAxis: {
                title: {
                    text: "number of items per day"
                },
                gridLineColor: "#ffffff"
            },
            plotOptions: {
                series: {
                    pointPadding: 0,
                    groupPadding: 0,
                    borderWidth: 0, 
                    shadow: true,
                    pointInterval: 24 * 3600 * 1000 // one day
                }
            },
            series: [
                {
                    name: "stories per day"
                }
            ]
        };
        
        $.getJSON('/api/frequency?since=100', function(data) {
            var d = data;
            var date = d[0][0].split('-');

            options.series[0].data = d;
            options.title["text"] = "news stories over the last " + d.length + " days"
            options.plotOptions.series.pointStart = Date.UTC(parseInt(date[0], 10), parseInt(date[1]-1, 10), parseInt(date[2], 10));
            
            var chart = new Highcharts.Chart(options);
        });
        
    });
