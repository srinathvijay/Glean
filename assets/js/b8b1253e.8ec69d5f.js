"use strict";(self.webpackChunkwebsite=self.webpackChunkwebsite||[]).push([[5925],{3905:function(e,t,n){n.r(t),n.d(t,{MDXContext:function(){return s},MDXProvider:function(){return p},mdx:function(){return h},useMDXComponents:function(){return d},withMDXComponents:function(){return u}});var a=n(67294);function r(e,t,n){return t in e?Object.defineProperty(e,t,{value:n,enumerable:!0,configurable:!0,writable:!0}):e[t]=n,e}function i(){return(i=Object.assign||function(e){for(var t=1;t<arguments.length;t++){var n=arguments[t];for(var a in n)Object.prototype.hasOwnProperty.call(n,a)&&(e[a]=n[a])}return e}).apply(this,arguments)}function o(e,t){var n=Object.keys(e);if(Object.getOwnPropertySymbols){var a=Object.getOwnPropertySymbols(e);t&&(a=a.filter((function(t){return Object.getOwnPropertyDescriptor(e,t).enumerable}))),n.push.apply(n,a)}return n}function c(e){for(var t=1;t<arguments.length;t++){var n=null!=arguments[t]?arguments[t]:{};t%2?o(Object(n),!0).forEach((function(t){r(e,t,n[t])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(n)):o(Object(n)).forEach((function(t){Object.defineProperty(e,t,Object.getOwnPropertyDescriptor(n,t))}))}return e}function l(e,t){if(null==e)return{};var n,a,r=function(e,t){if(null==e)return{};var n,a,r={},i=Object.keys(e);for(a=0;a<i.length;a++)n=i[a],t.indexOf(n)>=0||(r[n]=e[n]);return r}(e,t);if(Object.getOwnPropertySymbols){var i=Object.getOwnPropertySymbols(e);for(a=0;a<i.length;a++)n=i[a],t.indexOf(n)>=0||Object.prototype.propertyIsEnumerable.call(e,n)&&(r[n]=e[n])}return r}var s=a.createContext({}),u=function(e){return function(t){var n=d(t.components);return a.createElement(e,i({},t,{components:n}))}},d=function(e){var t=a.useContext(s),n=t;return e&&(n="function"==typeof e?e(t):c(c({},t),e)),n},p=function(e){var t=d(e.components);return a.createElement(s.Provider,{value:t},e.children)},f={inlineCode:"code",wrapper:function(e){var t=e.children;return a.createElement(a.Fragment,{},t)}},m=a.forwardRef((function(e,t){var n=e.components,r=e.mdxType,i=e.originalType,o=e.parentName,s=l(e,["components","mdxType","originalType","parentName"]),u=d(n),p=r,m=u["".concat(o,".").concat(p)]||u[p]||f[p]||i;return n?a.createElement(m,c(c({ref:t},s),{},{components:n})):a.createElement(m,c({ref:t},s))}));function h(e,t){var n=arguments,r=t&&t.mdxType;if("string"==typeof e||r){var i=n.length,o=new Array(i);o[0]=m;var c={};for(var l in t)hasOwnProperty.call(t,l)&&(c[l]=t[l]);c.originalType=e,c.mdxType="string"==typeof e?e:r,o[1]=c;for(var s=2;s<i;s++)o[s]=n[s];return a.createElement.apply(null,o)}return a.createElement.apply(null,n)}m.displayName="MDXCreateElement"},23074:function(e,t,n){n.r(t),n.d(t,{frontMatter:function(){return c},contentTitle:function(){return l},metadata:function(){return s},toc:function(){return u},default:function(){return p}});var a=n(87462),r=n(63366),i=(n(67294),n(3905)),o=(n(44256),["components"]),c={id:"advanced",title:"Advanced Query Features",sidebar_label:"Advanced Query Features"},l=void 0,s={unversionedId:"angle/advanced",id:"angle/advanced",isDocsHomePage:!1,title:"Advanced Query Features",description:"Types and signatures",source:"@site/docs/angle/advanced.md",sourceDirName:"angle",slug:"/angle/advanced",permalink:"/docs/angle/advanced",editUrl:"https://www.internalfb.com/intern/diffusion/FBS/browse/master/fbcode/glean/website/docs/angle/advanced.md",version:"current",frontMatter:{id:"advanced",title:"Advanced Query Features",sidebar_label:"Advanced Query Features"},sidebar:"someSidebar",previous:{title:"Query Efficiency",permalink:"/docs/angle/efficiency"},next:{title:"Debugging",permalink:"/docs/angle/debugging"}},u=[{value:"Types and signatures",id:"types-and-signatures",children:[]},{value:"Explicit fact IDs",id:"explicit-fact-ids",children:[]},{value:"Functional predicates",id:"functional-predicates",children:[]}],d={toc:u};function p(e){var t=e.components,n=(0,r.Z)(e,o);return(0,i.mdx)("wrapper",(0,a.Z)({},d,n,{components:t,mdxType:"MDXLayout"}),(0,i.mdx)("h2",{id:"types-and-signatures"},"Types and signatures"),(0,i.mdx)("p",null,"Angle queries are ",(0,i.mdx)("em",{parentName:"p"},"strongly typed"),": the server will check your query for type-safety before executing it. Type-checking ensures that the query makes sense; that it's not trying to pattern-match strings against integers, or look for a field in a record that doesn't exist for example."),(0,i.mdx)("p",null,"Angle's type-checker isn't very clever, though. It mostly doesn't do type ",(0,i.mdx)("em",{parentName:"p"},"inference"),", it checks that expressions have the intended type. When it doesn't know the intended type of an expression, it uses a dumb inference mode that can only infer the type when it's really obvious: like a fact match, or a string."),(0,i.mdx)("pre",null,(0,i.mdx)("code",{parentName:"pre",className:"language-lang=angle"},'facts> P where C = { name = "Fish" }; example.Parent { C, P }\ncan\'t infer the type of: {name = "Fish"}\n    try adding a type annotation like ({name = "Fish"} : T)\n    or reverse the statement (Q = P instead of P = Q)\n')),(0,i.mdx)("p",null,"In cases like this, Angle's type-checker needs a bit of help. We can use a ",(0,i.mdx)("em",{parentName:"p"},"type signature")," to supply more information about the type:"),(0,i.mdx)("pre",null,(0,i.mdx)("code",{parentName:"pre",className:"language-lang=angle"},'facts> P where C = { name = "Fish" } : example.Class; example.Parent { C, P }\n{ "id": 1024, "key": { "name": "Pet", "line": 10 } }\n')),(0,i.mdx)("p",null,"Here we used ",(0,i.mdx)("inlineCode",{parentName:"p"},'{ name = "Fish" } : example.Class'),' to tell Angle the expected type of the pattern. You should read the colon as "has type", and the type can be any valid Angle type, for details see ',(0,i.mdx)("a",{parentName:"p",href:"/docs/schema/types"},"Built-in types"),"."),(0,i.mdx)("h2",{id:"explicit-fact-ids"},"Explicit fact IDs"),(0,i.mdx)("p",null,"Every fact has an ID, which is a 64-bit integer that uniquely identifies the fact in a particular database. You've probably noticed these fact IDs in the query results: every result has an ",(0,i.mdx)("inlineCode",{parentName:"p"},"id")," field with the fact ID, and a ",(0,i.mdx)("inlineCode",{parentName:"p"},"key")," field with the fact key."),(0,i.mdx)("p",null,"Most Angle queries don't need to mention fact IDs explicitly, but sometimes it's useful. For example, you might need to perform a query to fetch some results, do some custom filtering on the results and then query Glean again using some of the fact IDs from the first query."),(0,i.mdx)("p",null,"WARNING: a fact ID only makes sense in the context of a particular database, so make sure that your query that mentions fact IDs is being made on the same database that you obtained the fact ID from originally."),(0,i.mdx)("p",null,"Glean has a syntax for referring to fact IDs directly; for example"),(0,i.mdx)("pre",null,(0,i.mdx)("code",{parentName:"pre",className:"language-lang=angle"},'facts> $1026 : example.Class\n{ "id": 1026, "key": { "name": "Fish", "line": 30 } }\n')),(0,i.mdx)("p",null,"the syntax is ",(0,i.mdx)("inlineCode",{parentName:"p"},"$<fact ID>"),", but you will often want to use it with a ",(0,i.mdx)("a",{parentName:"p",href:"#types-and-signatures"},"type signature"),", as ",(0,i.mdx)("inlineCode",{parentName:"p"},"$<fact ID> : <predicate>"),"."),(0,i.mdx)("p",null,"If you get the predicate wrong, Glean will complain:"),(0,i.mdx)("pre",null,(0,i.mdx)("code",{parentName:"pre",className:"language-lang=angle"},"facts> $1026 : example.Parent\n*** Exception: fact has the wrong type\n")),(0,i.mdx)("p",null,"The type can be omitted only if it is clear from the context, for example"),(0,i.mdx)("pre",null,(0,i.mdx)("code",{parentName:"pre",className:"language-lang=angle"},'facts> example.Parent { child = $1026 }\n{ "id": 1029, "key": { "child": { "id": 1026 }, "parent": { "id": 1024 } } }\n')),(0,i.mdx)("p",null,"Sometimes you might want to use multiple fact IDs in a query. Or-patterns come in handy here:"),(0,i.mdx)("pre",null,(0,i.mdx)("code",{parentName:"pre",className:"language-lang=angle"},"facts> example.Parent { child = $1026 | $1027 }\n")),(0,i.mdx)("h2",{id:"functional-predicates"},"Functional predicates"),(0,i.mdx)("p",null,"All the predicates we've seen so far have been key-only predicates. A predicate can also have a ",(0,i.mdx)("em",{parentName:"p"},"value"),"; we call these ",(0,i.mdx)("em",{parentName:"p"},"functional predicates")," or ",(0,i.mdx)("em",{parentName:"p"},"key-value predicates"),"."),(0,i.mdx)("p",null,"For example, we might model a reference to a class in our example schema like this:"),(0,i.mdx)("pre",null,(0,i.mdx)("code",{parentName:"pre",className:"language-lang=angle"},"predicate Reference :\n  { file : string, line : nat, column : nat } -> Class\n")),(0,i.mdx)("p",null,"This says that for a given (file,line,column) there can be at most one reference to a Class.  This uniqueness is the important property of a key-value predicate: for each key there is at most one value."),(0,i.mdx)("p",null,"We query for key-value predicates using this syntax:"),(0,i.mdx)("pre",null,(0,i.mdx)("code",{parentName:"pre",className:"language-lang=angle"},'facts> C where example.Reference { file = "x", line = 1, column = 2 } -> C\n')),(0,i.mdx)("p",null,"The pattern after the ",(0,i.mdx)("inlineCode",{parentName:"p"},"->")," matches the value. It can be an arbitrary pattern, just like the key. Note that facts cannot be efficiently searched by value, so the pattern that matches the value is a filter only."))}p.isMDXComponent=!0},47596:function(e,t,n){var a=this&&this.__awaiter||function(e,t,n,a){return new(n||(n=Promise))((function(r,i){function o(e){try{l(a.next(e))}catch(t){i(t)}}function c(e){try{l(a.throw(e))}catch(t){i(t)}}function l(e){var t;e.done?r(e.value):(t=e.value,t instanceof n?t:new n((function(e){e(t)}))).then(o,c)}l((a=a.apply(e,t||[])).next())}))};Object.defineProperty(t,"__esModule",{value:!0}),t.getSpecInfo=void 0;const r=n(11737);t.getSpecInfo=function(e){return a(this,void 0,void 0,(function*(){return yield r.call({module:"bloks",api:"getSpecInfo",args:{styleId:e}})}))}},11737:function(e,t){var n=this&&this.__awaiter||function(e,t,n,a){return new(n||(n=Promise))((function(r,i){function o(e){try{l(a.next(e))}catch(t){i(t)}}function c(e){try{l(a.throw(e))}catch(t){i(t)}}function l(e){var t;e.done?r(e.value):(t=e.value,t instanceof n?t:new n((function(e){e(t)}))).then(o,c)}l((a=a.apply(e,t||[])).next())}))};Object.defineProperty(t,"__esModule",{value:!0}),t.call=void 0;let a=!1,r=0;const i={};t.call=function(e){return n(this,void 0,void 0,(function*(){if("staticdocs.thefacebook.com"!==window.location.hostname&&"localhost"!==window.location.hostname)return Promise.reject(new Error("Not running on static docs"));a||(a=!0,window.addEventListener("message",(e=>{if("static-docs-bridge-response"!==e.data.event)return;const t=e.data.id;t in i||console.error(`Recieved response for id: ${t} with no matching receiver`),"response"in e.data?i[t].resolve(e.data.response):i[t].reject(new Error(e.data.error)),delete i[t]})));const t=r++,n=new Promise(((e,n)=>{i[t]={resolve:e,reject:n}})),o={event:"static-docs-bridge-call",id:t,module:e.module,api:e.api,args:e.args},c="localhost"===window.location.hostname?"*":"https://www.internalfb.com";return window.parent.postMessage(o,c),n}))}},24855:function(e,t,n){var a=this&&this.__awaiter||function(e,t,n,a){return new(n||(n=Promise))((function(r,i){function o(e){try{l(a.next(e))}catch(t){i(t)}}function c(e){try{l(a.throw(e))}catch(t){i(t)}}function l(e){var t;e.done?r(e.value):(t=e.value,t instanceof n?t:new n((function(e){e(t)}))).then(o,c)}l((a=a.apply(e,t||[])).next())}))};Object.defineProperty(t,"__esModule",{value:!0}),t.reportFeatureUsage=t.reportContentCopied=void 0;const r=n(11737);t.reportContentCopied=function(e){return a(this,void 0,void 0,(function*(){const{textContent:t}=e;try{yield r.call({module:"feedback",api:"reportContentCopied",args:{textContent:t}})}catch(n){}}))},t.reportFeatureUsage=function(e){return a(this,void 0,void 0,(function*(){const{featureName:t,id:n}=e;console.log("used feature");try{yield r.call({module:"feedback",api:"reportFeatureUsage",args:{featureName:t,id:n}})}catch(a){}}))}},44256:function(e,t,n){var a=this&&this.__createBinding||(Object.create?function(e,t,n,a){void 0===a&&(a=n),Object.defineProperty(e,a,{enumerable:!0,get:function(){return t[n]}})}:function(e,t,n,a){void 0===a&&(a=n),e[a]=t[n]}),r=this&&this.__setModuleDefault||(Object.create?function(e,t){Object.defineProperty(e,"default",{enumerable:!0,value:t})}:function(e,t){e.default=t}),i=this&&this.__importStar||function(e){if(e&&e.__esModule)return e;var t={};if(null!=e)for(var n in e)"default"!==n&&Object.prototype.hasOwnProperty.call(e,n)&&a(t,e,n);return r(t,e),t};Object.defineProperty(t,"__esModule",{value:!0}),t.OssOnly=t.FbInternalOnly=t.isInternal=t.validateFbContentArgs=t.fbInternalOnly=t.fbContent=t.inpageeditor=t.feedback=t.uidocs=t.bloks=void 0,t.bloks=i(n(47596)),t.uidocs=i(n(17483)),t.feedback=i(n(24855)),t.inpageeditor=i(n(27312));const o=["internal","external"];function c(e){return s(e),u()?"internal"in e?l(e.internal):[]:"external"in e?l(e.external):[]}function l(e){return"function"==typeof e?e():e}function s(e){if("object"!=typeof e)throw new Error(`fbContent() args must be an object containing keys: ${o}. Instead got ${e}`);if(!Object.keys(e).find((e=>o.find((t=>t===e)))))throw new Error(`No valid args found in ${JSON.stringify(e)}. Accepted keys: ${o}`);const t=Object.keys(e).filter((e=>!o.find((t=>t===e))));if(t.length>0)throw new Error(`Unexpected keys ${t} found in fbContent() args. Accepted keys: ${o}`)}function u(){try{return Boolean(!1)}catch(e){return console.log("process.env.FB_INTERNAL couldn't be read, maybe you forgot to add the required webpack EnvironmentPlugin config?",e),!1}}t.fbContent=c,t.fbInternalOnly=function(e){return c({internal:e})},t.validateFbContentArgs=s,t.isInternal=u,t.FbInternalOnly=function(e){return u()?e.children:null},t.OssOnly=function(e){return u()?null:e.children}},27312:function(e,t,n){var a=this&&this.__awaiter||function(e,t,n,a){return new(n||(n=Promise))((function(r,i){function o(e){try{l(a.next(e))}catch(t){i(t)}}function c(e){try{l(a.throw(e))}catch(t){i(t)}}function l(e){var t;e.done?r(e.value):(t=e.value,t instanceof n?t:new n((function(e){e(t)}))).then(o,c)}l((a=a.apply(e,t||[])).next())}))};Object.defineProperty(t,"__esModule",{value:!0}),t.submitDiff=void 0;const r=n(11737);t.submitDiff=function(e){return a(this,void 0,void 0,(function*(){const{file_path:t,new_content:n,project_name:a}=e;try{return yield r.call({module:"inpageeditor",api:"createPhabricatorDiffApi",args:{file_path:t,new_content:n,project_name:a}})}catch(i){throw new Error(`Error occurred while trying to submit diff. Stack trace: ${i}`)}}))}},17483:function(e,t,n){var a=this&&this.__awaiter||function(e,t,n,a){return new(n||(n=Promise))((function(r,i){function o(e){try{l(a.next(e))}catch(t){i(t)}}function c(e){try{l(a.throw(e))}catch(t){i(t)}}function l(e){var t;e.done?r(e.value):(t=e.value,t instanceof n?t:new n((function(e){e(t)}))).then(o,c)}l((a=a.apply(e,t||[])).next())}))};Object.defineProperty(t,"__esModule",{value:!0}),t.getApi=t.docsets=void 0;const r=n(11737);t.docsets={BLOKS_CORE:"887372105406659"},t.getApi=function(e){return a(this,void 0,void 0,(function*(){const{name:t,framework:n,docset:a}=e;return yield r.call({module:"uidocs",api:"getApi",args:{name:t,framework:n,docset:a}})}))}}}]);