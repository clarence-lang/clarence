
(= utils (require "./utils"))

(def Uniq uniq store (do
  (= this.parent uniq
     this.store  (:))
  (if store (over name of store
    (= this.store[of] name)))
  this))

(= Uniq.prototype.find (fn func (do
  (= uniq this)
  (while (? uniq)
    (if (= ref (func.call uniq)) (break)
        (= uniq uniq.parent)) ref))))

(= Uniq.prototype.findOut (fn func
  (if (? this.parent) (this.parent.find func))))

(= Uniq.prototype.has (fn key (in key (Object.keys this.store))))

(= Uniq.prototype.conflict (fn key
  (this.findOut {this.has key})))

(= Uniq.prototype.resolve (fn key (do
  (= oldkey key)
  (while (this.conflict key)
    (= key (utils.plusname key)))
  (= this.store[key] (= this.store[oldkey] (fn name
    (name.replace (RegExp (+ "^" oldkey)) key)))))))

(= Uniq.prototype.checkAndReplace (fn name (do
  ; get service part of name
  (= key (utils.getServicePart name))
  ; check if we have already defined replacement, define if not
  (if (not (this.has key))
    (this.resolve key))
  ; replace and return
  (this.store[key] name))))


(= module.exports Uniq)
