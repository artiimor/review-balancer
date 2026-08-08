# frozen_string_literal: true

module Repositories
  module Holidays
    class HolidaysController < ApplicationController
      before_action :authenticate_user!
      before_action :set_repository_and_contributor

      def index
        @holidays = @contributor.holidays.order(start_date: :desc)
      end

      def new
        @holiday = @contributor.holidays.new
      end

      def create
        @holiday = @contributor.holidays.new(holiday_params)

        if @holiday.save
          render turbo_stream: holiday_created_streams
        else
          render turbo_stream: turbo_stream.replace('holiday-modal',
                                                    partial: 'repositories/holidays/holidays/modal',
                                                    locals: { holiday: @holiday })
        end
      end

      def edit
        @holiday = @contributor.holidays.find(params[:id])
      end

      def update
        @holiday = @contributor.holidays.find(params[:id])

        if @holiday.update(holiday_params)
          render turbo_stream: [turbo_stream.remove('holiday-modal'),
                                turbo_stream.replace(@holiday,
                                                     partial: 'repositories/holidays/holidays/holiday',
                                                     locals: { holiday: @holiday })]
        else
          render turbo_stream: turbo_stream.replace('holiday-modal',
                                                    partial: 'repositories/holidays/holidays/modal',
                                                    locals: { holiday: @holiday })
        end
      end

      def destroy
        @holiday = @contributor.holidays.find(params[:id])
        @holiday.destroy

        render turbo_stream: holiday_destroyed_streams
      end

      private

      def set_repository_and_contributor
        @repository = current_user.repositories.find(params[:repository_id])
        @contributor = @repository.contributors.unscope(where: :active).find(params[:contributor_id])
      end

      def holiday_params
        params.require(:holiday).permit(:start_date, :end_date)
      end

      def holiday_created_streams
        [turbo_stream.remove('holiday-modal'),
         turbo_stream.remove('no-holidays'),
         turbo_stream.append('holidays',
                             partial: 'repositories/holidays/holidays/holiday',
                             locals: { holiday: @holiday }),
         holiday_count_stream]
      end

      def holiday_destroyed_streams
        streams = [turbo_stream.remove(@holiday), holiday_count_stream]
        if @contributor.holidays.none?
          streams << turbo_stream.append('holidays', partial: 'repositories/holidays/holidays/empty_state')
        end
        streams
      end

      def holiday_count_stream
        turbo_stream.replace('holiday-count',
                             partial: 'repositories/holidays/holidays/count',
                             locals: { holidays: @contributor.holidays })
      end
    end
  end
end
