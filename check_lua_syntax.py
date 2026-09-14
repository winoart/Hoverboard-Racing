import sys
import re

def check_balance(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Remove comments and strings to avoid false positives
    content = re.sub(r'--\[\[.*?\]\]', '', content, flags=re.DOTALL)
    content = re.sub(r'--.*', '', content)
    content = re.sub(r'".*?"', '""', content)
    content = re.sub(r"'.*?'", "''", content)
    
    tokens = re.findall(r'\b(if|for|while|function|do|end|repeat|until)\b', content)
    
    opens = ['if', 'for', 'while', 'function', 'do', 'repeat']
    closes = ['end', 'until']
    
    # Note: 'if' pairs with 'end', 'for' with 'end' (via 'do', but 'for' implies a block),
    # actually 'for' always has 'do', 'while' always has 'do'. 
    # 'if' has 'end'. 'function' has 'end'.
    # A simple count isn't perfect but let's see.
    stack = []
    
    lines = content.split('\n')
    for i, line in enumerate(lines):
        # find all tokens in the line
        tokens_in_line = re.findall(r'\b(if|function|do|end)\b', line)
        # simplistic heuristic for single line if statements: 'if ... then ... end'
        # let's just push and pop for each token
        for word in tokens_in_line:
            if word in ['if', 'function', 'do']:
                stack.append((word, i + 1, line.strip()))
            elif word == 'end':
                if stack:
                    stack.pop()
                else:
                    print(f"Unmatched 'end' found at line {i+1}: {line.strip()}")
                    return
                
    if len(stack) > 0:
        print(f"Unclosed blocks:")
        for s in stack:
            print(f"  Line {s[1]}: {s[0]} -> {s[2]}")
    else:
        print("Blocks balanced!")

check_balance(sys.argv[1])
