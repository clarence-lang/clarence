(ns web.server)

(def http (js/require "http"))
(defn handler [request]
  { :status 200
    :headers
    { "Content-type" "text/html" }
    :body "Hello, World!"
  })

(defn process [req res handler]

  (let [response (handler req)
  status (get response :status 200)
  headers (get response :headers {"Content-type" "text/html"})
  body (get response :body "")]
  (.writeHead res (status (to-object headers)))
  (.end res (body))))

(defn run [handler port]
    (.listen (.createServer http
      ((fn [req res] (process req res handler))))
      (port))
      (println "Server listening at port " port)
      (println "Visit: http://localhost:3000"))
(run handler 3000)
