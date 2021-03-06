#
# Makefile to build the 3D specific library - libm3d.a
#

include ../Rules.make

INCS	= static_3d.h dynamic_declarations_3d.h dynamic_allocations_3d.h
LIB	= $(LIBDIR)/lib3d${buildtype}.a

TEXSRC	= m3d.F90 variables_3d.F90 vertical_coordinates.F90 \
	  sigma_coordinates.F90 general_coordinates.F90 adaptive_coordinates.F90 check_h.F90 hcc_check.F90 \
	  advection_3d.F90 adv_split_w.F90 \
	  temperature.F90 salinity.F90 eqstate.F90 \
	  internal_pressure.F90 ip_blumberg_mellor.F90 ip_blumberg_mellor_lin.F90 ip_z_interpol.F90  ip_song_wright.F90 ip_chu_fan.F90 ip_shchepetkin_mcwilliams.F90 ip_stelling_vankester.F90 \
          bdy_3d.F90 rivers.F90 spm.F90 \
	  start_macro.F90 uu_momentum_3d.F90 vv_momentum_3d.F90 ww_momentum_3d.F90 uv_advect_3d.F90 uv_diffusion_3d.F90 stop_macro.F90 \
	  shear_frequency.F90 buoyancy_frequency.F90 stresses_3d.F90 gotm.F90 tke_eps_advect_3d.F90 physical_dissipation_3d.F90 numerical_mixing.F90 physical_mixing.F90 structure_friction_3d.F90

MOD = \
$(LIB)(variables_3d.o)		\
$(LIB)(vertical_coordinates.o)	\
$(LIB)(advection_3d.o)

ifneq ($(GETM_NO_BAROCLINIC),true)
MOD += \
$(LIB)(temperature.o)			\
$(LIB)(salinity.o)			\
$(LIB)(eqstate.o)
endif

MOD += \
$(LIB)(nonhydrostatic.o)		\
$(LIB)(internal_pressure.o)

ifeq ($(GETM_SPM),true)
MOD += \
$(LIB)(spm.o)
endif

ifeq ($(FABM),true)
MOD += $(LIB)(getm_fabm.o)
endif

ifeq ($(GETM_BIO),true)
MOD += $(LIB)(getm_bio.o)
endif

MOD += \
$(LIB)(bdy_3d.o)			\
$(LIB)(m3d.o)				\
$(LIB)(rivers.o)

OBJ = \
$(LIB)(start_macro.o)			\
$(LIB)(hcc_check.o)			\
$(LIB)(sigma_coordinates.o)		\
$(LIB)(general_coordinates.o)		\
$(LIB)(hybrid_coordinates.o)		\
$(LIB)(adaptive_coordinates.o)		\
$(LIB)(preadapt_coordinates.o)		\
$(LIB)(uu_momentum_3d.o)		\
$(LIB)(vv_momentum_3d.o)		\
$(LIB)(ww_momentum_3d.o)		\
$(LIB)(momentum_3d.o)		\
$(LIB)(velocity_update_3d.o)
ifeq ($(GETM_STRUCTURE_FRICTION),true)
OBJ += \
$(LIB)(structure_friction_3d.o)
endif

OBJ += \
$(LIB)(deformation_rates_3d.o)		\
$(LIB)(uv_advect_3d.o)			\
$(LIB)(uv_diffusion_3d.o)               \
$(LIB)(physical_dissipation_3d.o)	\
$(LIB)(ip_blumberg_mellor.o)		\
$(LIB)(ip_blumberg_mellor_lin.o)	\
$(LIB)(ip_z_interpol.o)			\
$(LIB)(ip_song_wright.o)		\
$(LIB)(ip_shchepetkin_mcwilliams.o)     \
$(LIB)(ip_stelling_vankester.o)		\
$(LIB)(ip_chu_fan.o)

ifneq ($(GETM_NO_BAROCLINIC),true)
OBJ += \
$(LIB)(buoyancy_frequency.o)		\
$(LIB)(numerical_mixing.o)		\
$(LIB)(physical_mixing.o)		\
$(LIB)(tracer_stirring.o)		\
$(LIB)(tracer_diffusion.o)
endif

OBJ += \
$(LIB)(eddyviscosity.o)			\
$(LIB)(adv_split_w.o)			\
$(LIB)(stresses_3d.o)			\
$(LIB)(shear_frequency.o)		\
$(LIB)(gotm.o)				\
$(LIB)(check_h.o)			\
$(LIB)(tke_eps_advect_3d.o)		\
$(LIB)(stop_macro.o)


all: modules objects

modules: $(MOD)

objects: $(OBJ)

$(MOD): $(INCS)

$(OBJ): $(MOD)

tests: test_eqstate

test_eqstate: modules objects test_eqstate.o
	$(FC) -o $@ $@.o $(LDFLAGS) $(LIB)
	$(RM) $@.o
	./$@

doc: $(TEXSRC)
	$(PROTEX) $(TEXSRC) > $(DOCDIR)/3d.tex
	touch doc

clean:
	$(RM) $(LIB) $(MODDIR)/m3d.{m.mod}

realclean: clean
	$(RM) *.o doc

distclean: realclean

#-----------------------------------------------------------------------
# Copyright (C) 2001 - Hans Burchard and Karsten Bolding (BBH)         !
#-----------------------------------------------------------------------
