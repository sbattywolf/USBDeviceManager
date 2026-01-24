import re
p='artifacts/run-21301595551/final-report-reviewed.html'
try:
    with open(p,encoding='utf-8') as f:
        s=f.read()
    i=s.find('<body')
    if i==-1:
        print('NO_BODY')
    else:
        j=s.find('>',i)
        k=s.find('</body>',j)
        body=s[j+1:k] if k!=-1 else s[j+1:]
        txt=re.sub('<[^>]+>','',body)
        txt=txt.strip()
        print('BODY_SNIPPET:\n')
        print(txt[:1200])
except Exception as e:
    print('ERR',e)
