import yaml,sys
p=''.join(open('.github/workflows/ci.yml','r',encoding='utf-8').readlines())
try:
    yaml.safe_load(p)
    print('YAML_SAFE_LOAD_OK')
except Exception as e:
    print('YAML_SAFE_LOAD_ERROR')
    print(e)
    sys.exit(1)
