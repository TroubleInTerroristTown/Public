<html>  
    <head>  
        <title>CSGO Webshortcuts fix by boomix</title>  
    </head>  
    <body>  
        <script type="text/javascript" >  
            function getAllUrlParams(url) { 
              var queryString = url ? url.split('?')[1] : window.location.search.slice(1); 
              var obj = {}; 
              if (queryString) { 
                queryString = queryString.split('#')[0]; 
                var arr = queryString.split('&'); 
                for (var i=0; i<arr.length; i++) { 
                  var a = arr[i].split('='); 
                  var paramNum = undefined; 
                  var paramName = a[0].replace(/\[\d*\]/, function(v) { 
                    paramNum = v.slice(1,-1); 
                    return ''; 
                  }); 
                  var paramValue = typeof(a[1])==='undefined' ? true : a[1]; 
                  paramName = paramName.toLowerCase(); 
                  paramValue = paramValue.toLowerCase(); 
                  if (obj[paramName]) { 
                    if (typeof obj[paramName] === 'string') { 
                      obj[paramName] = [obj[paramName]]; 
                    } 
                    if (typeof paramNum === 'undefined') { 
                      obj[paramName].push(paramValue); 
                    } 
                    else { 
                      obj[paramName][paramNum] = paramValue; 
                    } 
                  } 
                  else { 
                    obj[paramName] = paramValue; 
                  } 
                } 
              } 
              return obj; 
            } 


            var str = getAllUrlParams().web;  
            var full = getAllUrlParams().fullsize;  
            var height = getAllUrlParams().height; 
            var width = getAllUrlParams().width; 

            if (full == 1) {  
                window.open(str, "_blank", "toolbar=yes, fullscreen=yes, scrollbars=yes, width=" + screen.width + ", height=" + (screen.height - 72));  
setTimeout(function(){ 
                window.location.replace("http://deadsite.notworking"); 
}, 3000);       
    } else {  
                //Set the default width and height for if it's not defined  
                if (height === undefined || height === null || height == "")  
                {  
                    height = 720;  
                }  
                if (width === undefined || width === null || width == "")  
                {  
                    width = 960;  
                }  
                window.open(str, "_blank", "toolbar=yes, scrollbars=yes, resizable=yes, fullscreen=no, width=" + width + ", height=" + height);

       setTimeout(function(){ 
                window.location.replace("http://deadsite.notworking"); 
}, 3000);     
  }  
        </script>  
    </body>  
</html>