classdef TDMarkerPointManager < handle
    % TDMarkerPointManager. Part of the internal gui for the Pulmonary Toolkit.
    %
    %     You should not use this class within your own code. It is intended to
    %     be used internally within the gui of the Pulmonary Toolkit.
    %
    %     TDMarkerPointManager provides functionality for creating, editing and
    %     deleting marker points associated with an image using the
    %     TDViewerPanel.
    %
    %
    %     Licence
    %     -------
    %     Part of the TD Pulmonary Toolkit. http://code.google.com/p/pulmonarytoolkit
    %     Author: Tom Doel, 2012.  www.tomdoel.com
    %     Distributed under the GNU GPL v3 licence. Please see website for details.
    %
    
    properties
        % When a marker is placed in close proximity to an existing marker of
        % the same colour, we assume that the user is actually trying to replace
        % the marker.
        ClosestDistanceForReplaceMarker = 10
    end
    
    properties (SetAccess = private)
        
        % Keep a record of when we have unsaved changes to markers
        MarkerImageHasChanged = false
        
    end
    
    properties (SetAccess = private, SetObservable)
        
        % The colour that new markers will be set to
        CurrentColour
        
        % Whether marker positions are displayed
        ShowTextLabels = true
    end
    
    properties (Access = private)
        MarkerPointImage
        MarkerPoints
        AxesHandle
        ViewerPanel
        CurrentlyHighlightedMarker
        SliceNumber
        Orientation
        CoordinateLimits
        LockCallback = false
        Enabled = false
        DefaultColour = 3;
        IsDragging = false
    end
    
    methods
        function obj = TDMarkerPointManager(viewer_panel, axes_handle)
            obj.ViewerPanel = viewer_panel;
            obj.AxesHandle = axes_handle;
            obj.MarkerPointImage = TDMarkerPointImage;
        end
        
        function ChangeMarkerImage(obj, new_image)
            obj.MarkerPointImage.ChangeMarkerSubImage(new_image);
            obj.MarkerImageChanged;
            obj.MarkerImageHasChanged = false;
        end
        
        function Enable(obj, enable)
            if (enable && ~obj.Enabled)
                obj.ConvertMarkerImageToPoints(obj.ViewerPanel.SliceNumber(obj.ViewerPanel.Orientation), obj.ViewerPanel.Orientation);
            end
            
            if (~enable && obj.Enabled)
                obj.RemoveAllPoints;
            end
            
            obj.Enabled = enable;
        end
        
        function NewSliceOrOrientation(obj)
            if obj.Enabled
                if ~obj.LockCallback
                    obj.RemoveAllPoints;
                    obj.ConvertMarkerImageToPoints(obj.ViewerPanel.SliceNumber(obj.ViewerPanel.Orientation), obj.ViewerPanel.Orientation);
                end
            end
        end
        
        function ImageChanged(obj)
            obj.MarkerPointImage.BackgroundImageChanged(obj.ViewerPanel.BackgroundImage.BlankCopy);
            obj.MarkerImageChanged;
            obj.MarkerImageHasChanged = false;
        end
        
        function MarkerImageChanged(obj)
            if obj.Enabled
                if ~obj.LockCallback
                    obj.RemoveAllPoints;
                    obj.ConvertMarkerImageToPoints(obj.ViewerPanel.SliceNumber(obj.ViewerPanel.Orientation), obj.ViewerPanel.Orientation);
                end
            end
        end
        
        function ChangeShowTextLabels(obj, show)
            obj.ShowTextLabels = show;
            if obj.Enabled
                if obj.ShowTextLabels
                    obj.ShowAllTextLabels;
                else
                    obj.HideAllTextLabels;
                end
            end
        end
        
        function MouseDown(obj, ~)
            obj.IsDragging = false;
        end
        
        function AlertDragging(obj)
            obj.IsDragging = true;
        end
        
        function MouseMoved(obj, coords)
            if obj.Enabled
                closest_marker = obj.GetMarkerForThisPoint(coords, []);
                if isempty(closest_marker)
                    obj.HighlightNone;
                else
                    obj.HighlightMarker(closest_marker);
                end
            end
        end        
        
        function MouseUp(obj, coords)
            if obj.Enabled
                if ~obj.IsDragging
                    closest_marker = obj.GetMarkerForThisPoint(coords, obj.CurrentColour);
                    if isempty(closest_marker)
                        current_colour = obj.CurrentColour;
                        if isempty(current_colour)
                            current_colour = obj.DefaultColour;
                        end;
                        
                        new_marker = obj.NewMarker(coords, current_colour);
                        obj.HighlightMarker(new_marker);
                    else
                        closest_marker.ChangePosition(coords);
                    end
                end
            end
        end

        function image_coords = GetImageCoordinates(obj, coords)
            image_coords = zeros(1, 3);
            i_screen = coords(2);
            j_screen = coords(1);
            k_screen = obj.ViewerPanel.SliceNumber(obj.ViewerPanel.Orientation);
            
            switch obj.ViewerPanel.Orientation
                case TDImageOrientation.Coronal
                    image_coords(1) = k_screen;
                    image_coords(2) = j_screen;
                    image_coords(3) = i_screen;
                case TDImageOrientation.Sagittal
                    image_coords(1) = j_screen;
                    image_coords(2) = k_screen;
                    image_coords(3) = i_screen;
                case TDImageOrientation.Axial
                    image_coords(1) = i_screen;
                    image_coords(2) = j_screen;
                    image_coords(3) = k_screen;
            end
        end
        
        
        function RemoveThisMarker(obj, marker)
            for index = 1: length(obj.MarkerPoints)
                indexed_marker = obj.MarkerPoints(index);
                if indexed_marker == marker
                    if (marker == obj.CurrentlyHighlightedMarker)
                        obj.CurrentlyHighlightedMarker = [];
                    end
                    obj.MarkerPoints(index) = [];
                    return;
                end
            end
        end
        
        function DeleteHighlightedMarker(obj)
            if ~isempty(obj.CurrentlyHighlightedMarker)
                obj.CurrentlyHighlightedMarker.DeleteMarker;
            end
        end
        
        function ChangeCurrentColour(obj, new_colour)
            obj.CurrentColour = new_colour;
        end
        
        function AddPointToMarkerImage(obj, marker_position, colour)
            obj.LockCallback = true;
            coords = obj.GetImageCoordinates(marker_position);
            coords = max(1, coords);
            image_size = obj.MarkerPointImage.GetImageSize;
            coords(1) = min(coords(1), image_size(1));
            coords(2) = min(coords(2), image_size(2));
            coords(3) = min(coords(3), image_size(3));
            
            if obj.MarkerPointImage.ChangeMarkerPoint(coords, colour)
                obj.MarkerImageHasChanged = true;
            end
            
            obj.LockCallback = false;
        end
        
        % Find the image slice containing the last marker
        function GotoPreviousMarker(obj)
            maximum_skip = obj.ViewerPanel.SliceSkip;
            orientation = obj.ViewerPanel.Orientation;
            current_coordinate = obj.ViewerPanel.SliceNumber(orientation);
            index_of_nearest_marker = obj.MarkerPointImage.GetIndexOfPreviousMarker(current_coordinate, maximum_skip, orientation);
            obj.ViewerPanel.SliceNumber(orientation) = index_of_nearest_marker;
        end
        
        function GotoNextMarker(obj)
            maximum_skip = obj.ViewerPanel.SliceSkip;
            orientation = obj.ViewerPanel.Orientation;
            current_coordinate = obj.ViewerPanel.SliceNumber(orientation);
            index_of_nearest_marker =  obj.MarkerPointImage.GetIndexOfNextMarker(current_coordinate, maximum_skip, orientation);            
            obj.ViewerPanel.SliceNumber(orientation) = index_of_nearest_marker;
        end
        
        function GotoNearestMarker(obj)
            orientation = obj.ViewerPanel.Orientation;
            current_coordinate = obj.ViewerPanel.SliceNumber(orientation);
            index_of_nearest_marker = obj.MarkerPointImage.GetIndexOfNearestMarker(current_coordinate, orientation);
            obj.ViewerPanel.SliceNumber(orientation) = index_of_nearest_marker;
        end
        
        function GotoFirstMarker(obj)
            orientation = obj.ViewerPanel.Orientation;
            index_of_nearest_marker = obj.MarkerPointImage.GetIndexOfFirstMarker(orientation);
            obj.ViewerPanel.SliceNumber(orientation) = index_of_nearest_marker;
        end
        
        function GotoLastMarker(obj)
            orientation = obj.ViewerPanel.Orientation;
            index_of_nearest_marker = obj.MarkerPointImage.GetIndexOfLastMarker(orientation);
            obj.ViewerPanel.SliceNumber(orientation) = index_of_nearest_marker;
        end
        
        function MarkerPointsHaveBeenSaved(obj)
            obj.MarkerImageHasChanged = false;
        end
        
        function marker_image = GetMarkerImage(obj)
            marker_image = obj.MarkerPointImage.GetMarkerImage;
        end

    end

    methods (Access = private)
        function ConvertMarkerImageToPoints(obj, slice_number, dimension)
            if obj.MarkerPointImage.MarkerImageExists
                obj.Orientation = dimension;
                obj.SliceNumber = slice_number;
                
                [slice_markers, slice_size] = obj.MarkerPointImage.GetMarkersFromImage(slice_number, dimension);
                
                obj.CoordinateLimits = slice_size;
                
                for marker_s = slice_markers
                    marker = marker_s{1};
                    obj.NewMarker([marker.x, marker.y], marker.colour);
                end
            end
        end
                
        function new_marker = NewMarker(obj, coords, colour)
            new_marker = TDMarkerPoint(coords, obj.AxesHandle, colour, obj, obj.CoordinateLimits);
            
            if isempty(obj.MarkerPoints)
                obj.MarkerPoints = new_marker;
            else
                obj.MarkerPoints(end+1) = new_marker;
            end
            
            if (obj.ShowTextLabels)
                new_marker.AddTextLabel;
            end
        end
        
        function ShowAllTextLabels(obj)
            for marker = obj.MarkerPoints
                marker.AddTextLabel;
            end
        end

        function HideAllTextLabels(obj)
            for marker = obj.MarkerPoints
                marker.RemoveTextLabel;
            end
        end
        
        function HighlightNone(obj)
            if ~isempty(obj.CurrentlyHighlightedMarker)
                obj.CurrentlyHighlightedMarker.HighlightOff;
                obj.CurrentlyHighlightedMarker = [];
            end
        end
        
        function HighlightMarker(obj, marker)
            if isempty(obj.CurrentlyHighlightedMarker) || (obj.CurrentlyHighlightedMarker ~= marker)
                obj.HighlightNone;
                marker.Highlight;
                obj.CurrentlyHighlightedMarker = marker;
            end
        end
        
        function closest_marker = GetMarkerForThisPoint(obj, coords, desired_colour)
            [closest_marker, closest_distance] = obj.GetNearestMarker(coords, desired_colour);
            if closest_distance > obj.ClosestDistanceForReplaceMarker
                closest_marker = [];
            end
        end
        
        function [closest_point, closest_distance] = GetNearestMarker(obj, coords, desired_colour)
            closest_point = [];
            closest_distance = [];
            for marker = obj.MarkerPoints
                if isempty(desired_colour) || (desired_colour == marker.Colour)
                    point_position = marker.GetPosition;
                    distance = sum(abs(coords - point_position)); % Cityblock distance
                    if isempty(closest_distance) || (distance < closest_distance)
                        closest_distance = distance;
                        closest_point = marker;
                    end
                end
            end
        end
        
        function RemoveAllPoints(obj)
            obj.CurrentlyHighlightedMarker = [];
            for marker = obj.MarkerPoints
                marker.RemoveGraphic;
            end
            obj.MarkerPoints = [];
        end
        
    end
end

