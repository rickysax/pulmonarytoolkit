classdef PTKAirwayCentreline < PTKPlugin
    % PTKAirwayCentreline. Plugin for finding the centreline and radius of the pulmonary airway tree.
    %
    %     This is a plugin for the Pulmonary Toolkit. Plugins can be run using 
    %     the gui, or through the interfaces provided by the Pulmonary Toolkit.
    %     See PTKPlugin.m for more information on how to run plugins.
    %
    %     Plugins should not be run directly from your code.
    %
    %     PTKAirwayCentreline calls the PTKAirways plugin to segment the airway
    %     tree. It then uses the PTKSkeletonise library routine to reduce the
    %     airway tree to a centreline. The results are stored in a heirarchical
    %     tree structure.
    %
    %     Radius values are computed by examining planes perpendicular to the
    %     centreline and interpolating, using a FWHM method.
    %
    %     The output image generated by GenerateImageFromResults creates a
    %     colour-coded segmentation image showing skeleton points as colour 1,
    %     bifurcation points as 3 and removed internal loop points as 6.
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. https://github.com/tomdoel/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %    
    
    
    
    properties
        ButtonText = 'Airway <BR>Centreline'
        ToolTip = 'Show airway skeletonisation results processed globally'
        Category = 'Airways'

        AllowResultsToBeCached = true
        AlwaysRunPlugin = false
        PluginType = 'ReplaceOverlay'
        HidePluginInDisplay = false
        FlattenPreviewImage = true
        PTKVersion = '1'
        ButtonWidth = 6
        ButtonHeight = 2
        GeneratePreview = true
        Visibility = 'Developer'
    end
    
    methods (Static)
        function results = RunPlugin(dataset, reporting)
            lung_image = dataset.GetResult('PTKLungROI');
            radius_approximation = dataset.GetResult('PTKAirwayRadiusApproximation');
            centreline_results = dataset.GetResult('PTKAirwaySkeleton');
            
            if PTKSoftwareInfo.GraphicalDebugMode
                
                % For visualisation purposes
                airway_results = dataset.GetResult('PTKAirways');
                airway_segmented_image = PTKGetImageFromAirwayResults(airway_results.AirwayTree, lung_image, false, reporting);
                figure_airways_3d = figure;
                
                % Remove small structures
                removed_voxels = PTKAirwayCentreline.RemoveTrailingEndpoints(airway_results.AirwayTree);
                removed_voxels = airway_segmented_image.GlobalToLocalIndices(removed_voxels);
                airway_results_raw = airway_segmented_image.RawImage;
                airway_results_raw(airway_results_raw == 3) = 0;
                airway_results_raw(removed_voxels) = 0;
                airway_segmented_image.ChangeRawImage(airway_results_raw);
                
                MimVisualiseIn3D(figure_airways_3d, airway_segmented_image, 0.5, true, false, 0, CoreSystemUtilities.BackwardsCompatibilityColormap, reporting);
            else
                figure_airways_3d = [];
            end

            
            results = PTKGetRadiusForAirways(centreline_results, lung_image, radius_approximation, reporting, figure_airways_3d);
        end
        
        function removed_voxels = RemoveTrailingEndpoints(airway_tree)
            removed_voxels = [];
            voxel_limit = 150;
            next_segments = airway_tree;
            while ~isempty(next_segments)
                segment = next_segments(end);
                next_segments(end) = [];
                children = segment.Children;
                next_segments = [next_segments children];
                if isempty(children)
                    voxels = segment.GetAllAirwayPoints;
                    if numel(voxels) < voxel_limit
                        removed_voxels = [removed_voxels; voxels];
                    end
                    
                end
            end
        end
        

        function results = GenerateImageFromResults(skeleton_results, image_templates, ~)
            template_image = image_templates.GetTemplateImage(PTKContext.LungROI);

            new_image = zeros(template_image.ImageSize, 'uint8');
            new_image(template_image.GlobalToLocalIndices(skeleton_results.OriginalCentrelinePoints)) = 2;
            new_image(template_image.GlobalToLocalIndices(skeleton_results.CentrelinePoints)) = 1;
            new_image(template_image.GlobalToLocalIndices(skeleton_results.RemovedPoints)) = 6;
            new_image(template_image.GlobalToLocalIndices(skeleton_results.BifurcationPoints)) = 3;
            
            results = template_image.BlankCopy;
            results.ChangeRawImage(new_image);
            results.ImageType = PTKImageType.Colormap;
            
            results.SetVoxelToThis(skeleton_results.StartPoint, 4);
            
        end
    end
end
