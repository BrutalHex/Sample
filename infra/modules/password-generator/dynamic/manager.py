# module/manager.py
import json
import sys
import os

def main():
    query = json.loads(sys.stdin.read())
    operation = query['operation']
    previous_str = query.get('previous', '{}')
    try:
        previous = json.loads(previous_str)
        swap_parity = int(previous.get('swap_parity', 0))
        rotate_parity_a = int(previous.get('rotate_parity_a', 0))
        rotate_parity_b = int(previous.get('rotate_parity_b', 0))
    except json.JSONDecodeError:
        swap_parity = 0
        rotate_parity_a = 0
        rotate_parity_b = 0

    is_swapped = swap_parity % 2 == 1
    if operation == 'rotate':
        if is_swapped:
            rotate_parity_a += 1
        else:
            rotate_parity_b += 1
    elif operation == 'swap':
        swap_parity += 1
    elif operation == 'none':
        pass
    else:
        print(json.dumps({'error': 'Invalid operation'}))
        sys.exit(1)

    print(json.dumps({
        'swap_parity': str(swap_parity),
        'rotate_parity_a': str(rotate_parity_a),
        'rotate_parity_b': str(rotate_parity_b),
    }))

if __name__ == '__main__':
    main()