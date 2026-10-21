"""Topology and backwards-compatibility checks for architectural mask strokes."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import numpy as np

spec=importlib.util.spec_from_file_location('landscape',Path(__file__).resolve().parents[1]/'tools/build_landscape_world_mask.py')
mask=importlib.util.module_from_spec(spec)
spec.loader.exec_module(mask)


class ClosedBandTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.old_paths=mask.OUT,mask.CACHE
        mask.OUT=mask.CACHE=Path(self.tmp.name)

    def tearDown(self):
        mask.OUT,mask.CACHE=self.old_paths
        self.tmp.cleanup()

    @staticmethod
    def circle():
        angle=np.linspace(0,2*np.pi,721)
        return {'closed':True,'width_m':6.,'points_xy':np.c_[20*np.cos(angle),20*np.sin(angle)].tolist(),
                'heights':[[0,63.],[720,63.]]}

    @staticmethod
    def at(meta,sdf,x,z):
        p=((np.array([x,z])-meta['origin_xz'])/meta['extent_xz']*meta['resolution']).astype(int)
        return float(sdf[p[1],p[0]])

    def test_closed_ring_has_hole_and_no_start_seam(self):
        meta,sdf,height=mask.build_mask({'native_center':[0,0,0],'curves':[self.circle()]},128)
        self.assertGreater(self.at(meta,sdf,0,0),0.)
        self.assertGreater(self.at(meta,sdf,26,0),0.)
        # Both sides of the sampled start point remain inside the same band.
        for x,z in [(20,.7),(20,-.7),(-20,0),(0,20),(0,-20)]:
            self.assertLess(self.at(meta,sdf,x,z),-2.)

    def test_open_stroke_can_fill_the_closed_rings_hole(self):
        line={'width_m':4.,'points_xy':np.c_[np.linspace(-30,30,121),np.zeros(121)].tolist(),
              'heights':[[0,63.],[120,63.]]}
        meta,sdf,_=mask.build_mask({'native_center':[0,0,0],'curves':[line,self.circle()]},128)
        self.assertLess(self.at(meta,sdf,0,0),-1.)
        self.assertGreater(self.at(meta,sdf,0,10),0.)

    def test_closed_width_is_constant_and_duplicate_endpoint_is_removed(self):
        p,loops,half,height=mask.curve_band(self.circle(),np.array([0.,0.,0.]))
        self.assertEqual(len(p),720)
        self.assertEqual(len(loops),2)
        np.testing.assert_array_equal(half,np.full(720,3.))
        np.testing.assert_allclose(np.linalg.norm(loops[0]-loops[1],axis=1),6.,atol=1e-10)

    def test_existing_open_stroke_geometry_stays_identical(self):
        p=np.array([[0.,0.],[2.,1.],[6.,3.],[10.,0.]])
        c={'width_m':8.,'points_xy':p.tolist(),'heights':[[0,10.],[3,14.]]}
        q,loops,half,height=mask.curve_band(c,np.array([0.,0.,0.]))
        p[:,1]*=-1
        length=np.r_[0,np.cumsum(np.linalg.norm(np.diff(p,axis=0),axis=1))]
        old_half=4.*np.maximum(.005,np.sin(np.pi*length/max(length[-1],1))**.4)
        tangent=np.gradient(p,axis=0);tangent/=np.maximum(np.linalg.norm(tangent,axis=1,keepdims=True),1e-8)
        normal=np.c_[-tangent[:,1],tangent[:,0]]
        old_polygon=np.r_[p+normal*old_half[:,None],(p-normal*old_half[:,None])[::-1]]
        np.testing.assert_array_equal(half,old_half)
        np.testing.assert_array_equal(loops[0],old_polygon)


if __name__=='__main__':
    unittest.main()
