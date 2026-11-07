import numpy as np, rooms as R

def best(pulls, labels, want):
    ok = np.array([l in want for l in labels])
    if not ok.any(): return None
    ang = np.degrees(np.arctan2(pulls[:,1], pulls[:,0])); st = np.linalg.norm(pulls, axis=1)
    a0, s0 = np.median(ang[ok]), np.median(st[ok])
    i = np.argmin(np.where(ok, (ang-a0)**2 + ((st-s0)/4)**2, 1e9))
    return tuple(np.round(pulls[i]).astype(int))

def mk3(wx=600, ww=60, wt=300, cy=230, step=560, well=(720, 590), vine=(240, 450)):
    room = R.mkroom({'roof': [(0,0),(1280,0),(1280,cy),(step,cy),(step,110),(260,110),(240,147),(220,110),(0,110)],
        'lwall': [(0,110),(30,110),(30,720),(0,720)], 'floor': [(30,650),(1250,650),(1250,720),(30,720)],
        'wall': [(wx,650),(wx,wt),(wx+ww,wt),(wx+ww,650)],
        'rwall': [(1250,110),(1280,110),(1280,720),(1250,720)]}, [well])
    def lab(r):
        if r['kind'] == 'well': return 'WELL direct'
        if r['kind'] != 'rock': return 'miss: ' + r['kind']
        s = R.surface(r['n']); x, y = r['contact']
        if s == 'ceiling' and r['vn'] >= 70:
            d = R.drip(room, r['pos'][0], y + R.R + 6)
            if d['kind'] == 'well': return 'DRIP->well'
            return 'miss: drip on wall top' if d.get('poly') == 'wall' else ('miss: drip behind wall' if r['pos'][0] > wx+ww else 'miss: drip in front')
        if r['poly'] == 'wall' and s == 'wall': return 'miss: wall face glide to floor'
        return f"miss: {r['poly']} {s}"
    return room, vine, lab

def mk6(wx=520, wt=330, cy=250, step=480, anvil=(640, 720), atop=450, pods=((585, 600), (790, 600)), vine=(230, 450)):
    a0, a1 = anvil
    room = R.mkroom({'roof': [(0,0),(1280,0),(1280,cy),(step,cy),(step,110),(250,110),(230,147),(210,110),(0,110)],
        'lwall': [(0,110),(30,110),(30,720),(0,720)], 'floor': [(30,650),(1250,650),(1250,720),(30,720)],
        'wall': [(wx,650),(wx,wt),(wx+50,wt),(wx+50,650)],
        'anvil': [(a0,atop),(a1,atop),(a1+25,atop+30),(a1+25,650),(a0-25,650),(a0-25,atop+30)],
        'rwall': [(1250,110),(1280,110),(1280,720),(1250,720)]}, list(pods))
    def lab(r):
        if r['kind'] == 'well': return 'miss: one pod direct'
        if r['kind'] != 'rock': return 'miss: ' + r['kind']
        s = R.surface(r['n']); x, y = r['contact']
        if s == 'ceiling' and r['vn'] >= 70:
            d = R.fly(np.array([[r['pos'][0], y+18]]), np.array([[0.0, 90.0]]), room, skip_wells=True)[0]
            if d['kind'] == 'rock' and d['poly'] == 'anvil' and R.surface(d['n']) == 'floor':
                return 'DRIP->anvil SPLIT' if d['vn'] >= 520 else 'miss: drip too soft'
            return 'miss: drip ' + (d.get('poly') or d['kind'])
        if r['poly'] == 'anvil' and s == 'floor':
            return 'miss: anvil hit, lopsided' if r['vn'] >= 520 else 'miss: anvil hit, soft'
        return f"miss: {r['poly']} {s}"
    return room, vine, lab

if __name__ == '__main__':
    import sys
    for name, (room, vine, lab), want in [('room 3', mk3(), {'DRIP->well'}), ('room 6', mk6(), {'DRIP->anvil SPLIT'})]:
        p, l, r = R.sweep(room, vine, lab)
        R.report(name, p, l, r, want)
        b = best(p, l, want)
        if b: R.show(room, vine, b, lab, '(median pick)')

def mk6b(wx=520, wt=330, lip=(480, 600, 250), high=150, anvil=(660, 740), atop=520, pods=((600, 610), (800, 610)), vine=(230, 450)):
    a0, a1 = anvil; l0, l1, ly = lip
    room = R.mkroom({'roof': [(0,0),(1280,0),(1280,high),(l1,high),(l1,ly),(l0,ly),(l0,110),(250,110),(230,147),(210,110),(0,110)],
        'lwall': [(0,110),(30,110),(30,720),(0,720)], 'floor': [(30,650),(1250,650),(1250,720),(30,720)],
        'wall': [(wx,650),(wx,wt),(wx+50,wt),(wx+50,650)],
        'anvil': [(a0,atop),(a1,atop),(a1+25,atop+30),(a1+25,650),(a0-25,650),(a0-25,atop+30)],
        'rwall': [(1250,110),(1280,110),(1280,720),(1250,720)]}, list(pods))
    def lab(r):
        if r['kind'] == 'well': return 'miss: one pod direct'
        if r['kind'] != 'rock': return 'miss: ' + r['kind']
        s = R.surface(r['n']); x, y = r['contact']
        if s == 'ceiling' and r['vn'] >= 70:
            d = R.fly(np.array([[r['pos'][0], y+18]]), np.array([[0.0, 90.0]]), room, skip_wells=True)[0]
            if d['kind'] == 'rock' and d['poly'] == 'anvil' and R.surface(d['n']) == 'floor':
                return 'DRIP->anvil SPLIT' if d['vn'] >= 520 else 'miss: drip too soft'
            return 'miss: drip ' + (d.get('poly') or d['kind'])
        if r['poly'] == 'anvil' and s == 'floor':
            return 'miss: anvil hit, lopsided' if r['vn'] >= 520 else 'miss: anvil hit, soft'
        return f"miss: {r['poly']} {s}"
    return room, vine, lab

K_SPLIT = 0.35
def mk6c(top=(590, 670), ty=470, vine=(230, 450), pods=None):
    a0, a1 = top
    room = R.mkroom({'roof': R.roof(230), 'lwall': [(0,110),(30,110),(30,720),(0,720)],
        'floor': [(30,650),(1250,650),(1250,720),(30,720)],
        'anvil': [(a0,ty),(a1,ty),(a1+20,ty+20),(a1+20,650),(a0-20,650),(a0-20,ty+20)],
        'rwall': [(1250,110),(1280,110),(1280,720),(1250,720)]}, pods or [(0, -999)])
    def halves(r):
        vx, vn = r['vel'][0], r['vn']
        out = []
        for sgn in (-1, 1):
            u = vx + sgn * K_SPLIT * vn            # speed along the top, + = right
            edge = a1 if u > 0 else a0
            x, y, t = edge + (8.5 if u > 0 else -8.5), ty - 8.5, 0.0
            vy = 0.0
            while y < 640:                          # ballistic off the edge, half radius 8.5
                vy += R.G * R.DT; x += u * R.DT; y += vy * R.DT
                u *= R.DECAY; vy *= R.DECAY
                if (u > 0 and x < a1 + 28) or (u < 0 and x > a0 - 28):  # still beside the anvil body
                    pass
                if y > 600: break
            out.append((sgn, x))
        return out
    def lab(r):
        if r['kind'] == 'well': return 'miss: one pod direct'
        if r['kind'] != 'rock': return 'miss: ' + r['kind']
        s = R.surface(r['n'])
        if r['poly'] == 'anvil' and s == 'floor':
            if r['vn'] < 520: return 'miss: anvil, soft (film stays)'
            if abs(r['vel'][0]) >= K_SPLIT * r['vn']: return 'miss: anvil, lopsided split'
            return 'SPLIT both ways'
        return f"miss: {r['poly']} {s}"
    return room, vine, lab, halves
